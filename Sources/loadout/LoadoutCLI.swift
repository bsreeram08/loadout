import ArgumentParser
import Darwin
import Foundation
import LoadoutCore

@main
struct LoadoutCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "loadout",
        abstract: "Local-first per-service environment profiles for macOS terminals.",
        subcommands: [
            Export.self,
            Select.self,
            Deselect.self,
            Order.self,
            Status.self,
            List.self,
            Set.self,
            Unset.self,
            Import.self,
            MigrateKeychain.self,
            RepairAccess.self,
            Reload.self,
        ],
        defaultSubcommand: Status.self
    )
}

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Emit shell-eval-able export lines for the current selection."
    )

    func run() throws {
        let result = try ExportEngine().export()
        for warning in result.warnings {
            FileHandle.standardError.write(Data((warning + "\n").utf8))
        }
        for line in result.lines {
            print(line)
        }
    }
}

struct Select: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Select a variant for a service (opt-in). Run with no arguments for interactive mode."
    )

    @Argument(help: "Service name, e.g. worldline")
    var service: String?

    @Argument(help: "Variant name, e.g. prod")
    var variant: String?

    mutating func validate() throws {
        switch (service, variant) {
        case (nil, nil), (.some, .some):
            return
        default:
            throw ValidationError(
                "Provide both service and variant, or run `loadout select` with no arguments."
            )
        }
    }

    func run() throws {
        if let service, let variant {
            _ = try StateStore().select(service: service, variant: variant)
            print("selected \(service) → \(variant)")
            return
        }

        guard isatty(STDIN_FILENO) == 1 else {
            throw ValidationError(
                "Interactive select requires a TTY. Use: loadout select <service> <variant>"
            )
        }

        try SelectWizard().run()
    }
}

struct Deselect: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove a service from the active selection."
    )

    @Argument(help: "Service name")
    var service: String

    func run() throws {
        _ = try StateStore().deselect(service: service)
        print("deselected \(service)")
    }
}

struct Order: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Set service precedence for var collision resolution."
    )

    @Argument(help: "Ordered service names (first wins on collision)")
    var services: [String]

    func run() throws {
        for service in services {
            try NameValidator.validateService(service)
        }
        _ = try StateStore().setOrder(services)
        print("order: \(services.joined(separator: " → "))")
    }
}

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show the current selection and registry summary."
    )

    func run() throws {
        let state = try StateStore().load()
        let registry = try KeychainStore().registry()
        let engine = ExportEngine()

        if state.selection.isEmpty {
            print("selection: (empty — opt-in, nothing exports)")
        } else {
            print("selection:")
            for service in engine.orderedSelectionServices(state: state) {
                if let variant = state.selection[service] {
                    print("  \(service) → \(variant)")
                }
            }
        }

        if !state.order.isEmpty {
            print("order: \(state.order.joined(separator: " → "))")
        }

        if registry.isEmpty {
            print("registry: (empty — use loadout set or loadout import)")
        } else {
            print("registry:")
            for entry in registry {
                let counts = entry.variants
                    .map { "\($0)(\(entry.variableCounts[$0] ?? 0))" }
                    .joined(separator: ", ")
                print("  \(entry.service): \(counts)")
            }
        }

        print("keychain: \(LoadoutKeychain.path)")
        print("state: \(LoadoutPaths.stateFileURL.path)")
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List services and variants stored in Keychain."
    )

    func run() throws {
        let registry = try KeychainStore().registry()
        guard !registry.isEmpty else {
            print("no services in keychain")
            return
        }
        for entry in registry {
            for variant in entry.variants {
                let count = entry.variableCounts[variant] ?? 0
                print("\(entry.service)\t\(variant)\t\(count)")
            }
        }
    }
}

struct Set: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Store a variable in Keychain for a service/variant."
    )

    @Argument(help: "Service name")
    var service: String

    @Argument(help: "Variant name")
    var variant: String

    @Argument(help: "Environment variable name")
    var variable: String

    @Argument(help: "Secret value")
    var value: String

    func run() throws {
        try KeychainStore().set(
            service: service,
            variant: variant,
            variable: variable,
            value: value
        )
        print("stored \(service)/\(variant)/\(variable)")
    }
}

struct Unset: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove variables, variants, or entire services from Keychain."
    )

    @Argument(help: "Service name")
    var service: String

    @Argument(help: "Variant name (omit with --all)")
    var variant: String?

    @Argument(help: "Environment variable name (omit to delete all vars in variant)")
    var variable: String?

    @Flag(name: .long, help: "Delete every variant and variable for the service")
    var all: Bool = false

    @Flag(name: .long, help: "Delete every variable in the variant")
    var allVars: Bool = false

    mutating func validate() throws {
        if all {
            if variant != nil || variable != nil || allVars {
                throw ValidationError("Use only `loadout unset <service> --all` to delete a service.")
            }
            return
        }
        guard let variant else {
            throw ValidationError("Provide a variant, or use --all to delete the entire service.")
        }
        if allVars && variable != nil {
            throw ValidationError("Use either a variable name or --all-vars, not both.")
        }
        if variable == nil && !allVars {
            throw ValidationError(
                "Provide a variable name, or use --all-vars to delete every variable in the variant."
            )
        }
        _ = variant
    }

    func run() throws {
        let store = KeychainStore()
        let stateStore = StateStore()

        if all {
            let count = try store.deleteService(service)
            _ = try stateStore.removeServiceReferences(service)
            print("deleted service \(service) (\(count) variables)")
            return
        }

        guard let variant else { return }

        if allVars {
            let count = try store.deleteVariant(service: service, variant: variant)
            let state = try stateStore.load()
            if state.selection[service] == variant {
                _ = try stateStore.deselect(service: service)
            }
            print("deleted \(service)/\(variant) (\(count) variables)")
            return
        }

        guard let variable else { return }
        try store.deleteVariable(service: service, variant: variant, variable: variable)
        print("deleted \(service)/\(variant)/\(variable)")
    }
}

struct Import: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Import secrets from a .zshrc or .env file (interactive)."
    )

    @Option(name: .long, help: "Source file path")
    var from: String

    @Flag(name: .long, help: "Show import plan without writing Keychain or state")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Skip interactive prompts (required for prod in non-TTY)")
    var yes: Bool = false

    func run() throws {
        let path = NSString(string: from).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw LoadoutError.io("file not found: \(path)")
        }

        let importer = ZshrcImporter()
        let plan = try importer.plan(from: path)
        printImportPlan(plan)

        if dryRun {
            print("dry-run: no changes written")
            return
        }

        var approvedProd = yes
        if !plan.prodServices.isEmpty && !yes {
            print("")
            print("⚠️  prod variants will be activated for: \(plan.prodServices.joined(separator: ", "))")
            approvedProd = ConsolePrompt.requireYes(
                "Import will seed prod into selection. Rotated secrets only."
            )
            guard approvedProd else {
                print("aborted")
                throw ExitCode.failure
            }
        }

        if !yes {
            let proceed = ConsolePrompt.confirm(
                "Import \(plan.variableCount) variables across \(plan.serviceCount) services?",
                defaultYes: false
            )
            guard proceed else {
                print("aborted")
                throw ExitCode.failure
            }
        }

        let result = try importer.execute(plan: plan, approvedProd: approvedProd)
        print("imported \(result.importedVariables) variables")
        print("selection seeded:")
        for service in result.selection.keys.sorted() {
            print("  \(service) → \(result.selection[service]!)")
        }
    }

    private func printImportPlan(_ plan: ImportPlan) {
        print("source: \(plan.sourcePath)")
        print("services: \(plan.serviceCount), variables: \(plan.variableCount)")
        for warning in plan.warnings {
            FileHandle.standardError.write(Data(("loadout: \(warning)\n").utf8))
        }
        print("blocks:")
        for block in plan.blocks {
            let active = block.active.count
            let inactive = block.inactive.count
            let marker = block.active.isEmpty ? " " : "*"
            print("  \(marker) \(block.service)/\(block.variant): \(active) active, \(inactive) commented")
        }
        if plan.proposedSelection.isEmpty {
            print("proposed selection: (empty — no active exports found)")
        } else {
            print("proposed selection:")
            for service in plan.proposedSelection.keys.sorted() {
                print("  \(service) → \(plan.proposedSelection[service]!)")
            }
        }
    }
}

struct MigrateKeychain: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate-keychain",
        abstract: "Move secrets from login keychain to dedicated loadout keychain (one-time)."
    )

    func run() throws {
        let store = KeychainStore()
        let count = try store.migrateKeychain { message in
            FileHandle.standardError.write(Data((message + "\n").utf8))
        }
        print("migrated \(count) secrets to dedicated keychain")
        print(try store.accessPolicyDescription())
        print("rebuilds no longer require repair-access")
    }
}

struct RepairAccess: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "repair-access",
        abstract: "Re-apply Keychain ACLs on the dedicated loadout keychain."
    )

    func run() throws {
        let store = KeychainStore()
        let count = try store.repairAccess { message in
            FileHandle.standardError.write(Data((message + "\n").utf8))
        }
        print("refreshed ACL for \(count) service/variant groups")
        print(try store.accessPolicyDescription())
    }
}

struct Reload: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Hint for refreshing env in the current terminal."
    )

    func run() throws {
        print("Run reloadenv in this terminal (defined by the Loadout zshrc hook).")
        print("Already-open terminals cannot be updated automatically.")
    }
}