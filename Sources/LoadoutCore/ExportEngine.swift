import Foundation

public struct ExportEngine: Sendable {
    private let stateStore: StateStore
    private let keychain: KeychainStore

    public init(stateStore: StateStore = StateStore(), keychain: KeychainStore = KeychainStore()) {
        self.stateStore = stateStore
        self.keychain = keychain
    }

    public func export(catalog: KeychainCatalog? = nil) throws -> ExportResult {
        let state = try stateStore.load()
        guard !state.selection.isEmpty else {
            return ExportResult(lines: [], warnings: [])
        }

        let index = try catalog ?? KeychainCatalog()
        let orderedServices = orderedSelectionServices(state: state)
        var active: [String: String] = [:]
        var provenance: [String: String] = [:]
        var warnings: [String] = []

        for service in orderedServices {
            guard let variant = state.selection[service] else { continue }
            let variables = try keychain.variables(service: service, variant: variant, catalog: index)
            if variables.isEmpty {
                warnings.append(
                    "loadout: skipping \(service)/\(variant) — no keychain items found"
                )
                continue
            }

            for (key, value) in variables.sorted(by: { $0.key < $1.key }) {
                if let existingService = provenance[key] {
                    warnings.append(
                        "loadout: \(key) from \(service) shadowed by \(existingService) (order precedence)"
                    )
                    continue
                }
                active[key] = value
                provenance[key] = service
            }
        }

        let lines = active.keys.sorted().map { key in
            ShellQuoting.exportLine(key: key, value: active[key]!)
        }
        return ExportResult(lines: lines, warnings: warnings)
    }

    public func orderedSelectionServices(state: LoadoutState) -> [String] {
        let selected = Set(state.selection.keys)
        var result: [String] = []
        for service in state.order where selected.contains(service) {
            result.append(service)
        }
        let remaining = selected.subtracting(result).sorted()
        result.append(contentsOf: remaining)
        return result
    }
}