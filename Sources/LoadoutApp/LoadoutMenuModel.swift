import AppKit
import Foundation
import LoadoutCore

struct MenuContext {
    let registry: [RegistryEntry]
    let state: LoadoutState
    let summary: SelectionSummary
    let errorMessage: String?
}

@MainActor
final class LoadoutMenuModel: ObservableObject {
    @Published private(set) var context: MenuContext?
    @Published private(set) var loginEnabled = LoginItemController.isEnabled
    @Published var manageSelection: String?
    @Published private(set) var exportPreview = ""
    @Published private(set) var collisionOrder: [String] = []

    private let stateStore = StateStore()
    private let keychain = KeychainStore()
    private let exportEngine = ExportEngine()

    var hasProdSelected: Bool {
        context?.summary.hasProdSelected ?? false
    }

    var stateFilePath: String { LoadoutPaths.stateFileURL.path }
    var keychainPath: String { LoadoutKeychain.path }
    var cliPath: String { CLIInstaller.installURL.path }

    func refresh() {
        do {
            let registry = try keychain.registry()
            let state = try stateStore.load()
            let summary = SelectionSummary.compute(state: state, registry: registry)
            context = MenuContext(
                registry: registry,
                state: state,
                summary: summary,
                errorMessage: nil
            )
            collisionOrder = orderedServices(state: state, registry: registry)
            if manageSelection == nil {
                manageSelection = registry.first?.service
            } else if !registry.contains(where: { $0.service == manageSelection }) {
                manageSelection = registry.first?.service
            }
            refreshExportPreview()
        } catch {
            context = MenuContext(
                registry: [],
                state: LoadoutState(),
                summary: SelectionSummary(
                    selectedServiceCount: 0,
                    selectedVariableCount: 0,
                    hasProdSelected: false
                ),
                errorMessage: String(describing: error)
            )
            collisionOrder = []
            exportPreview = ""
        }
        loginEnabled = LoginItemController.isEnabled
    }

    func registryEntry(for service: String) -> RegistryEntry? {
        context?.registry.first { $0.service == service }
    }

    func selectedVariant(for service: String) -> String? {
        context?.state.selection[service]
    }

    func variableNames(service: String, variant: String) -> [String] {
        (try? keychain.variableNames(service: service, variant: variant)) ?? []
    }

    func select(service: String, variant: String) {
        apply {
            _ = try stateStore.select(service: service, variant: variant)
        }
    }

    func deselect(service: String) {
        apply {
            _ = try stateStore.deselect(service: service)
        }
    }

    func setVariable(service: String, variant: String, name: String, value: String) {
        apply {
            try keychain.set(service: service, variant: variant, variable: name, value: value)
        }
    }

    func deleteVariable(service: String, variant: String, name: String) {
        apply {
            try keychain.deleteVariable(service: service, variant: variant, variable: name)
        }
    }

    func deleteVariant(service: String, variant: String) {
        apply {
            let count = try keychain.deleteVariant(service: service, variant: variant)
            guard count >= 0 else { return }
            let state = try stateStore.load()
            if state.selection[service] == variant {
                _ = try stateStore.deselect(service: service)
            }
        }
    }

    func deleteService(_ service: String) {
        apply {
            _ = try keychain.deleteService(service)
            _ = try stateStore.removeServiceReferences(service)
        }
    }

    func moveOrder(from source: IndexSet, to destination: Int) {
        var order = collisionOrder
        order.move(fromOffsets: source, toOffset: destination)
        apply {
            _ = try stateStore.setOrder(order)
        }
    }

    func moveServiceUp(at index: Int) {
        guard index > 0 else { return }
        var order = collisionOrder
        order.swapAt(index, index - 1)
        apply {
            _ = try stateStore.setOrder(order)
        }
    }

    func moveServiceDown(at index: Int) {
        guard index < collisionOrder.count - 1 else { return }
        var order = collisionOrder
        order.swapAt(index, index + 1)
        apply {
            _ = try stateStore.setOrder(order)
        }
    }

    func toggleLogin() {
        do {
            try LoginItemController.setEnabled(!LoginItemController.isEnabled)
            loginEnabled = LoginItemController.isEnabled
        } catch {
            showAlert(
                title: "Launch at login",
                message: "Could not update login item: \(error.localizedDescription)\n\nStatus: \(LoginItemController.statusDescription)"
            )
        }
    }

    func openConfigFolder() {
        NSWorkspace.shared.selectFile(
            stateFilePath,
            inFileViewerRootedAtPath: LoadoutPaths.configDirectory.path
        )
    }

    func showReloadHint() {
        showAlert(
            title: "Reload open terminals",
            message: """
            Loadout cannot update already-open terminals automatically.

            In each open terminal, run:

                reloadenv

            New terminals load the active set from your .zshrc hook.
            """
        )
    }

    func showImportHint() {
        let zshrc = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".zshrc").path
        showAlert(
            title: "Import secrets",
            message: """
            Import from your shell config:

                loadout import --from \(zshrc)

            Or add variables from Manage → Add variable.
            """
        )
    }

    private func refreshExportPreview() {
        guard let result = try? exportEngine.export() else {
            exportPreview = ""
            return
        }
        var lines = result.lines
        for warning in result.warnings {
            lines.append("# \(warning)")
        }
        exportPreview = lines.joined(separator: "\n")
    }

    private func orderedServices(state: LoadoutState, registry: [RegistryEntry]) -> [String] {
        let known = Set(registry.map(\.service))
        var order = state.order.filter { known.contains($0) }
        let remaining = known.subtracting(order).sorted()
        order.append(contentsOf: remaining)
        return order
    }

    private func apply(_ change: () throws -> Void) {
        do {
            try change()
            refresh()
        } catch {
            showAlert(title: "Loadout", message: error.localizedDescription)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}