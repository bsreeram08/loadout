import Foundation
import Security

/// Single keychain scan indexed for registry and per-variant lookups.
public struct KeychainCatalog: Sendable {
    private struct Item: Sendable {
        let serviceAttr: String
        let parsed: ServiceVariant
        let account: String
    }

    private let items: [Item]
    private let namesByServiceVariant: [String: [String]]

    public init() throws {
        try LoadoutKeychain.ensureReady()
        let loaded = try Self.loadItems()
        items = loaded
        namesByServiceVariant = Self.indexNames(loaded)
    }

    public func registry() -> [RegistryEntry] {
        var grouped: [String: [String: Set<String>]] = [:]
        for item in items {
            grouped[item.parsed.service, default: [:]][item.parsed.variant, default: []]
                .insert(item.account)
        }

        return grouped.keys.sorted().map { service in
            let variants = grouped[service] ?? [:]
            let sortedVariants = variants.keys.sorted()
            let counts = Dictionary(uniqueKeysWithValues: sortedVariants.map { variant in
                (variant, variants[variant]?.count ?? 0)
            })
            return RegistryEntry(service: service, variants: sortedVariants, variableCounts: counts)
        }
    }

    public func variableNames(service: String, variant: String) -> [String] {
        namesByServiceVariant[Self.variantKey(service: service, variant: variant)] ?? []
    }

    public func variables(
        service: String,
        variant: String,
        reader: (_ serviceAttr: String, _ account: String) throws -> String?
    ) throws -> [String: String] {
        let serviceAttr = LoadoutPaths.keychainService(service: service, variant: variant)
        var result: [String: String] = [:]
        for account in variableNames(service: service, variant: variant) {
            if let value = try reader(serviceAttr, account) {
                result[account] = value
            }
        }
        return result
    }

    private static func variantKey(service: String, variant: String) -> String {
        "\(service)\u{1f}:\(variant)"
    }

    private static func indexNames(_ items: [Item]) -> [String: [String]] {
        var grouped: [String: Set<String>] = [:]
        for item in items {
            let key = variantKey(service: item.parsed.service, variant: item.parsed.variant)
            grouped[key, default: []].insert(item.account)
        }
        return grouped.mapValues { $0.sorted() }
    }

    private static func loadItems() throws -> [Item] {
        if ProcessInfo.processInfo.environment["LOADOUT_SKIP_PARTITION"] == "1" {
            return try queryLoadoutItems()
        }

        try LoadoutKeychain.ensureReady()
        // SecItemCopyMatching ignores the user search list; dump the dedicated file directly.
        let dedicated = try loadItemsFromKeychainFile(LoadoutKeychain.path)
        let login = try queryLoadoutItems()
        return mergeItems(dedicated: dedicated, login: login)
    }

    private static func loadItemsFromKeychainFile(_ path: String) throws -> [Item] {
        let text = try LoadoutKeychain.dumpKeychain(path)
        guard !text.isEmpty else { return [] }
        return parseDumpKeychain(text)
    }

    private static func parseDumpKeychain(_ text: String) -> [Item] {
        var items: [Item] = []
        var currentService: String?
        var currentAccount: String?
        var inGenp = false

        func flush() {
            guard inGenp,
                  let service = currentService,
                  let account = currentAccount,
                  let parsed = LoadoutPaths.parseKeychainService(service)
            else { return }
            items.append(Item(serviceAttr: service, parsed: parsed, account: account))
        }

        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("class:") {
                flush()
                inGenp = trimmed.contains("\"genp\"")
                currentService = nil
                currentAccount = nil
                continue
            }
            guard inGenp else { continue }
            if let service = parseDumpBlobAttribute(trimmed, names: ["svce", "0x00000007"]) {
                currentService = service
            } else if let account = parseDumpBlobAttribute(trimmed, names: ["acct"]) {
                currentAccount = account
            }
        }
        flush()
        return items
    }

    private static func parseDumpBlobAttribute(_ line: String, names: [String]) -> String? {
        for name in names where line.contains(name) {
            guard let start = line.range(of: "<blob>=\"")?.upperBound,
                  let end = line[start...].firstIndex(of: "\"")
            else { continue }
            return String(line[start..<end])
        }
        return nil
    }

    private static func queryLoadoutItems() throws -> [Item] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip,
        ]

        var found: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &found)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw LoadoutError.keychain(status)
        }

        let rows: [[String: Any]]
        if let one = found as? [String: Any] {
            rows = [one]
        } else if let many = found as? [[String: Any]] {
            rows = many
        } else {
            return []
        }

        return rows.compactMap { entry in
            guard let serviceAttr = entry[kSecAttrService as String] as? String,
                  let parsed = LoadoutPaths.parseKeychainService(serviceAttr),
                  let account = entry[kSecAttrAccount as String] as? String
            else { return nil }
            return Item(serviceAttr: serviceAttr, parsed: parsed, account: account)
        }
    }

    private static func mergeItems(dedicated: [Item], login: [Item]) -> [Item] {
        var seen = Set<String>()
        var merged: [Item] = []
        func key(_ item: Item) -> String { "\(item.serviceAttr)\u{1f}:\(item.account)" }

        for item in dedicated {
            let itemKey = key(item)
            seen.insert(itemKey)
            merged.append(item)
        }
        for item in login where !seen.contains(key(item)) {
            merged.append(item)
        }
        return merged
    }
}