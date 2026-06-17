import Foundation
import Security

public struct KeychainStore: Sendable {
    public init() {}

    public func set(service: String, variant: String, variable: String, value: String) throws {
        try NameValidator.validateService(service)
        try NameValidator.validateVariant(variant)
        try NameValidator.validateVariable(variable)
        let serviceAttr = LoadoutPaths.keychainService(service: service, variant: variant)
        try LoadoutKeychain.storeAllowAny(service: serviceAttr, account: variable, value: value)
    }

    public func deleteVariable(service: String, variant: String, variable: String) throws {
        try NameValidator.validateService(service)
        try NameValidator.validateVariant(variant)
        try NameValidator.validateVariable(variable)
        let serviceAttr = LoadoutPaths.keychainService(service: service, variant: variant)
        try LoadoutKeychain.delete(service: serviceAttr, account: variable)
    }

    @discardableResult
    public func deleteVariant(service: String, variant: String) throws -> Int {
        try NameValidator.validateService(service)
        try NameValidator.validateVariant(variant)
        let names = try variableNames(service: service, variant: variant)
        let serviceAttr = LoadoutPaths.keychainService(service: service, variant: variant)
        for name in names {
            try LoadoutKeychain.delete(service: serviceAttr, account: name)
        }
        return names.count
    }

    @discardableResult
    public func deleteService(_ service: String) throws -> Int {
        try NameValidator.validateService(service)
        let entry = try registry().first { $0.service == service }
        guard let entry else { return 0 }
        var deleted = 0
        for variant in entry.variants {
            deleted += try deleteVariant(service: service, variant: variant)
        }
        return deleted
    }

    public func get(service: String, variant: String, variable: String) throws -> String? {
        let serviceAttr = LoadoutPaths.keychainService(service: service, variant: variant)
        if ProcessInfo.processInfo.environment["LOADOUT_SKIP_PARTITION"] == "1" {
            return try getViaSecItem(serviceAttr: serviceAttr, account: variable)
        }
        try LoadoutKeychain.ensureReady()
        return try LoadoutKeychain.readSecret(
            keychain: LoadoutKeychain.path,
            service: serviceAttr,
            account: variable
        )
    }

    public func variables(service: String, variant: String) throws -> [String: String] {
        try LoadoutKeychain.ensureReady()
        let serviceAttr = LoadoutPaths.keychainService(service: service, variant: variant)
        let entries = try allLoadoutItems(includeData: false)
            .filter { $0.serviceAttr == serviceAttr }

        var result: [String: String] = [:]
        for entry in entries {
            if let value = try LoadoutKeychain.readSecret(
                keychain: LoadoutKeychain.path,
                service: serviceAttr,
                account: entry.account
            ) {
                result[entry.account] = value
            }
        }
        return result
    }

    public func variableNames(service: String, variant: String) throws -> [String] {
        try LoadoutKeychain.ensureReady()
        let serviceAttr = LoadoutPaths.keychainService(service: service, variant: variant)
        return try allLoadoutItems(includeData: false)
            .filter { $0.serviceAttr == serviceAttr }
            .map(\.account)
            .sorted()
    }

    public func registry() throws -> [RegistryEntry] {
        try LoadoutKeychain.ensureReady()
        let entries = try allLoadoutItems(includeData: false)
        var grouped: [String: [String: Set<String>]] = [:]
        for entry in entries {
            grouped[entry.parsed.service, default: [:]][entry.parsed.variant, default: []]
                .insert(entry.account)
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

    public func accessPolicyDescription() throws -> String {
        try LoadoutKeychain.ensureReady()
        return "\(LoadoutKeychain.path) (allow-any-app)"
    }

    /// One-time move from login keychain → dedicated loadout keychain.
    public func migrateKeychain(onProgress: ((String) -> Void)? = nil) throws -> Int {
        let report: (String) -> Void = onProgress ?? { message in
            FileHandle.standardError.write(Data((message + "\n").utf8))
        }

        try LoadoutKeychain.setLoginSearchList()
        let loginEntries = try allLoadoutItems(includeData: false)

        guard !loginEntries.isEmpty else {
            report("no loadout items in login keychain")
            return 0
        }

        report("authenticate (Touch ID or password)…")
        try KeychainAuthenticator.authenticateForRepair()

        report("reading \(loginEntries.count) secrets from login keychain…")
        var payloads: [(LoadoutItem, String)] = []
        for entry in loginEntries {
            guard let value = try LoadoutKeychain.readSecret(
                keychain: LoadoutKeychain.loginPath,
                service: entry.serviceAttr,
                account: entry.account
            ) else {
                continue
            }
            payloads.append((entry, value))
        }

        try LoadoutKeychain.ensureReady()
        let grouped = Dictionary(grouping: payloads, by: { $0.0.serviceAttr })

        for (index, serviceAttr) in grouped.keys.sorted().enumerated() {
            let items = grouped[serviceAttr] ?? []
            report("[\(index + 1)/\(grouped.count)] \(serviceAttr) (\(items.count) vars)")
            for (entry, value) in items {
                let alreadyInDedicated = try LoadoutKeychain.readSecret(
                    keychain: LoadoutKeychain.path,
                    service: entry.serviceAttr,
                    account: entry.account
                ) != nil
                if alreadyInDedicated {
                    report("  ↷ \(entry.account) (already in dedicated keychain)")
                } else {
                    report("  → \(entry.account)")
                    try LoadoutKeychain.storeAllowAny(
                        service: entry.serviceAttr,
                        account: entry.account,
                        value: value
                    )
                }
                try LoadoutKeychain.deleteFromLogin(service: entry.serviceAttr, account: entry.account)
            }
        }
        return payloads.count
    }

    /// No-op — kept for compatibility. `-A` items don't need per-rebuild repair.
    public func repairAccess(onProgress: ((String) -> Void)? = nil) throws -> Int {
        let report: (String) -> Void = onProgress ?? { message in
            FileHandle.standardError.write(Data((message + "\n").utf8))
        }
        try LoadoutKeychain.ensureReady()
        let count = try allLoadoutItems(includeData: false).count
        if count == 0 {
            report("no items in \(LoadoutKeychain.path) — run loadout migrate-keychain")
        } else {
            report("nothing to repair — dedicated keychain uses allow-any-app (-A)")
        }
        return count
    }

    private func getViaSecItem(serviceAttr: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceAttr,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            throw LoadoutError.keychain(status)
        }
        return value
    }

    private struct LoadoutItem {
        let serviceAttr: String
        let parsed: ServiceVariant
        let account: String
    }

    private func allLoadoutItems(includeData: Bool) throws -> [LoadoutItem] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip,
        ]
        if includeData {
            query[kSecReturnData as String] = true
        }

        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw LoadoutError.keychain(status)
        }

        let rows: [[String: Any]]
        if let one = items as? [String: Any] {
            rows = [one]
        } else if let many = items as? [[String: Any]] {
            rows = many
        } else {
            return []
        }

        return rows.compactMap { entry in
            guard let serviceAttr = entry[kSecAttrService as String] as? String,
                  let parsed = LoadoutPaths.parseKeychainService(serviceAttr),
                  let account = entry[kSecAttrAccount as String] as? String
            else { return nil }
            return LoadoutItem(serviceAttr: serviceAttr, parsed: parsed, account: account)
        }
    }
}