import Foundation

public struct SelectWizard: Sendable {
    public enum Action: Equatable, Sendable {
        case select(service: String, variant: String)
        case deselect(service: String)
        case quit
    }

    public struct IO: Sendable {
        public var write: @Sendable (String) -> Void
        public var writePrompt: @Sendable (String) -> Void
        public var readLine: @Sendable () -> String?

        public static let standard = IO(
            write: { print($0) },
            writePrompt: { prompt in
                print(prompt, terminator: "")
                fflush(stdout)
            },
            readLine: { Swift.readLine() }
        )
    }

    private let stateStore: StateStore
    private let keychain: KeychainStore

    public init(stateStore: StateStore = StateStore(), keychain: KeychainStore = KeychainStore()) {
        self.stateStore = stateStore
        self.keychain = keychain
    }

    public func run(io: IO = .standard) throws {
        let registry = try keychain.registry()
        guard !registry.isEmpty else {
            io.write("no services in keychain — use loadout set or loadout import")
            return
        }

        var state = try stateStore.load()

        while true {
            guard let action = try prompt(registry: registry, state: state, io: io) else {
                return
            }

            switch action {
            case .quit:
                return
            case .select(let service, let variant):
                state = try stateStore.select(service: service, variant: variant)
                io.write("selected \(service) → \(variant)")
            case .deselect(let service):
                state = try stateStore.deselect(service: service)
                io.write("deselected \(service)")
            }

            guard ConsolePrompt.confirm("Change another service?", defaultYes: false, io: io) else {
                return
            }
        }
    }

    func prompt(
        registry: [RegistryEntry],
        state: LoadoutState,
        io: IO
    ) throws -> Action? {
        io.write("")
        io.write("Services:")
        for (index, entry) in registry.enumerated() {
            let marker: String
            if let variant = state.selection[entry.service] {
                marker = "→ \(variant)"
            } else {
                marker = "(off)"
            }
            io.write("  \(index + 1). \(entry.service) \(marker)")
        }

        io.writePrompt("Pick service [1-\(registry.count), q]: ")
        guard let serviceInput = io.readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        if serviceInput.lowercased() == "q" {
            return .quit
        }
        guard let serviceIndex = Int(serviceInput), registry.indices.contains(serviceIndex - 1) else {
            io.write("invalid choice")
            return try prompt(registry: registry, state: state, io: io)
        }

        let entry = registry[serviceIndex - 1]
        return try promptVariant(registry: registry, state: state, entry: entry, io: io)
    }

    func promptVariant(
        registry: [RegistryEntry],
        state: LoadoutState,
        entry: RegistryEntry,
        io: IO
    ) throws -> Action? {
        let selected = state.selection[entry.service]
        io.write("")
        io.write("Variants for \(entry.service):")
        for (index, variant) in entry.variants.enumerated() {
            let count = entry.variableCounts[variant] ?? 0
            let noun = count == 1 ? "var" : "vars"
            let marker = variant == selected ? " *" : ""
            io.write("  \(index + 1). \(variant) (\(count) \(noun))\(marker)")
        }

        let deselectHint = selected == nil ? "" : ", d"
        io.write("  d. deselect")
        io.write("")
        io.writePrompt("Pick variant [1-\(entry.variants.count)\(deselectHint), b, q]: ")

        guard let variantInput = io.readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        let lower = variantInput.lowercased()
        if lower == "q" {
            return .quit
        }
        if lower == "b" {
            return try prompt(registry: registry, state: state, io: io)
        }
        if lower == "d" {
            guard selected != nil else {
                io.write("\(entry.service) is not selected")
                return try promptVariant(registry: registry, state: state, entry: entry, io: io)
            }
            return .deselect(service: entry.service)
        }

        guard let variantIndex = Int(variantInput), entry.variants.indices.contains(variantIndex - 1) else {
            io.write("invalid choice")
            return try promptVariant(registry: registry, state: state, entry: entry, io: io)
        }

        let variant = entry.variants[variantIndex - 1]
        return .select(service: entry.service, variant: variant)
    }
}