import AppKit
import Foundation
import LoadoutCore
import Observation

struct ActiveMenuEntry: Identifiable, Equatable {
    let service: String
    let entry: RegistryEntry?
    let variant: String

    var id: String { service }
}

struct MenuContext {
    let registry: [RegistryEntry]
    let state: LoadoutState
    let summary: SelectionSummary
    let errorMessage: String?
}

struct LoadoutAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

@Observable
@MainActor
final class LoadoutMenuModel {
    private(set) var context: MenuContext?
    private(set) var loginEnabled = LoginItemController.isEnabled
    var manageSelection: String?
    private(set) var exportPreview = ""
    private(set) var collisionOrder: [String] = []
    private(set) var isRefreshing = false
    var preferredWindowTab: LoadoutWindowTab = .services
    var alert: LoadoutAlert?

    private let stateStore = StateStore()
    private let keychain = KeychainStore()
    private let exportEngine = ExportEngine()
    private var catalog: KeychainCatalog?
    private var variableNamesByKey: [String: [String]] = [:]
    private var refreshGeneration: UInt = 0
    private var mutationGeneration: UInt = 0
    @ObservationIgnored nonisolated(unsafe) private var refreshObserver: NSObjectProtocol?

    init() {
        refreshObserver = NotificationCenter.default.addObserver(
            forName: .loadoutRefreshRequested,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.refresh(force: true)
            }
        }
        refresh()
    }

    deinit {
        if let refreshObserver {
            NotificationCenter.default.removeObserver(refreshObserver)
        }
    }

    var hasProdSelected: Bool {
        context?.summary.hasProdSelected ?? false
    }

    var stateFilePath: String { LoadoutPaths.stateFileURL.path }
    var keychainPath: String { LoadoutKeychain.path }
    var cliPath: String { CLIInstaller.installURL.path }

    func refresh(includeExportPreview: Bool = false, force: Bool = false) {
        if isRefreshing, !force, !includeExportPreview {
            return
        }
        refreshGeneration &+= 1
        let generation = refreshGeneration
        if context == nil {
            isRefreshing = true
        }
        Task { @MainActor [weak self] in
            await self?.performRefresh(
                includeExportPreview: includeExportPreview,
                generation: generation
            )
        }
    }

    func refreshIfStale() {
        guard context == nil else { return }
        refresh(force: true)
    }

    func registryEntry(for service: String) -> RegistryEntry? {
        context?.registry.first { $0.service == service }
    }

    func selectedVariant(for service: String) -> String? {
        context?.state.selection[service]
    }

    func activeMenuEntries() -> [ActiveMenuEntry] {
        guard let context else { return [] }
        let registryByService = Dictionary(
            uniqueKeysWithValues: context.registry.map { ($0.service, $0) }
        )
        let orderedServices = collisionOrder.filter { context.state.selection[$0] != nil }
        let unordered = context.state.selection.keys
            .filter { !collisionOrder.contains($0) }
            .sorted()
        return (orderedServices + unordered).compactMap { service in
            guard let variant = context.state.selection[service] else { return nil }
            return ActiveMenuEntry(
                service: service,
                entry: registryByService[service],
                variant: variant
            )
        }
    }

    func variableNames(service: String, variant: String) -> [String] {
        variableNamesByKey[Self.variantKey(service: service, variant: variant)] ?? []
    }

    func variableValue(service: String, variant: String, name: String) async throws -> String? {
        let keychain = KeychainStore()
        return try await Task.detached(priority: .userInitiated) {
            try keychain.get(service: service, variant: variant, variable: name)
        }.value
    }

    func select(service: String, variant: String) {
        mutate(keychainMutation: false, includeExportPreview: false) {
            let store = StateStore()
            _ = try store.select(service: service, variant: variant)
        }
    }

    func deselect(service: String) {
        mutate(keychainMutation: false, includeExportPreview: false) {
            let store = StateStore()
            _ = try store.deselect(service: service)
        }
    }

    func setVariable(service: String, variant: String, name: String, value: String) {
        mutate(keychainMutation: true, includeExportPreview: false) {
            let store = KeychainStore()
            try store.set(service: service, variant: variant, variable: name, value: value)
        }
    }

    func deleteVariable(service: String, variant: String, name: String) {
        mutate(keychainMutation: true, includeExportPreview: false) {
            let store = KeychainStore()
            try store.deleteVariable(service: service, variant: variant, variable: name)
        }
    }

    func deleteVariant(service: String, variant: String) {
        mutate(keychainMutation: true, includeExportPreview: false) {
            let kc = KeychainStore()
            let store = StateStore()
            let count = try kc.deleteVariant(service: service, variant: variant)
            guard count >= 0 else { return }
            let state = try store.load()
            if state.selection[service] == variant {
                _ = try store.deselect(service: service)
            }
        }
    }

    func deleteService(_ service: String) {
        mutate(keychainMutation: true, includeExportPreview: false) {
            let kc = KeychainStore()
            let store = StateStore()
            _ = try kc.deleteService(service)
            _ = try store.removeServiceReferences(service)
        }
    }

    func moveOrder(from source: IndexSet, to destination: Int) {
        var order = collisionOrder
        order.move(fromOffsets: source, toOffset: destination)
        applyOrder(order)
    }

    func moveServiceUp(at index: Int) {
        guard index > 0 else { return }
        var order = collisionOrder
        order.swapAt(index, index - 1)
        applyOrder(order)
    }

    func moveServiceDown(at index: Int) {
        guard index < collisionOrder.count - 1 else { return }
        var order = collisionOrder
        order.swapAt(index, index + 1)
        applyOrder(order)
    }

    private func applyOrder(_ order: [String]) {
        mutate(keychainMutation: false, includeExportPreview: true) {
            let store = StateStore()
            _ = try store.setOrder(order)
        }
    }

    func toggleLogin() {
        Task { @MainActor in
            do {
                try LoginItemController.setEnabled(!LoginItemController.isEnabled)
                loginEnabled = LoginItemController.isEnabled
            } catch {
                presentAlert(
                    title: "Launch at login",
                    message: "Could not update login item: \(error.localizedDescription)\n\nStatus: \(LoginItemController.statusDescription)"
                )
            }
        }
    }

    func openConfigFolder() {
        NSWorkspace.shared.selectFile(
            stateFilePath,
            inFileViewerRootedAtPath: LoadoutPaths.configDirectory.path
        )
    }

    func showReloadHint() {
        presentAlert(
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
        presentAlert(
            title: "Import secrets",
            message: """
            Import from your shell config:

                loadout import --from \(zshrc)

            Or add variables from Manage → Add variable.
            """
        )
    }

    private func performRefresh(includeExportPreview: Bool, generation: UInt) async {
        defer {
            if generation == refreshGeneration {
                isRefreshing = false
            }
        }

        do {
            let loadedCatalog = try await Task.detached(priority: .userInitiated) {
                try KeychainCatalog()
            }.value
            guard generation == refreshGeneration else { return }

            let state = try stateStore.load()
            let registry = loadedCatalog.registry()
            let summary = SelectionSummary.compute(state: state, registry: registry)
            let namesIndex = Self.variableNamesIndex(registry: registry, catalog: loadedCatalog)
            let order = orderedServices(state: state, registry: registry)
            guard generation == refreshGeneration else { return }
            catalog = loadedCatalog
            variableNamesByKey = namesIndex
            context = MenuContext(
                registry: registry,
                state: state,
                summary: summary,
                errorMessage: nil
            )
            collisionOrder = order
            sanitizeManageSelection(registry: registry)
            if includeExportPreview {
                let preview = await Task.detached(priority: .userInitiated) {
                    Self.buildExportPreview(catalog: loadedCatalog, exportEngine: ExportEngine())
                }.value
                guard generation == refreshGeneration else { return }
                exportPreview = preview
            }
        } catch {
            guard generation == refreshGeneration else { return }
            catalog = nil
            variableNamesByKey = [:]
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
            sanitizeManageSelection(registry: [])
        }
        guard generation == refreshGeneration else { return }
        loginEnabled = LoginItemController.isEnabled
    }

    private func mutate(
        keychainMutation: Bool,
        includeExportPreview: Bool,
        _ change: @escaping @Sendable () throws -> Void
    ) {
        mutationGeneration &+= 1
        let generation = mutationGeneration
        Task { @MainActor in
            do {
                try await Task.detached(priority: .userInitiated) {
                    try change()
                }.value
                guard generation == mutationGeneration else { return }
                if keychainMutation {
                    refresh(includeExportPreview: includeExportPreview)
                } else {
                    await updateContextFromState(includeExportPreview: includeExportPreview)
                }
            } catch {
                guard generation == mutationGeneration else { return }
                presentAlert(title: "Loadout", message: error.localizedDescription)
            }
        }
    }

    private func updateContextFromState(includeExportPreview: Bool) async {
        guard let registry = context?.registry else {
            refresh(includeExportPreview: includeExportPreview)
            return
        }
        do {
            let state = try stateStore.load()
            let summary = SelectionSummary.compute(state: state, registry: registry)
            context = MenuContext(
                registry: registry,
                state: state,
                summary: summary,
                errorMessage: nil
            )
            collisionOrder = orderedServices(state: state, registry: registry)
            if includeExportPreview, let catalog {
                let preview = await Task.detached(priority: .userInitiated) {
                    Self.buildExportPreview(catalog: catalog, exportEngine: ExportEngine())
                }.value
                exportPreview = preview
            }
        } catch {
            presentAlert(title: "Loadout", message: error.localizedDescription)
        }
    }

    private func sanitizeManageSelection(registry: [RegistryEntry]) {
        if let selection = manageSelection,
           registry.contains(where: { $0.service == selection })
        {
            return
        }
        manageSelection = registry.first?.service
    }

    private func orderedServices(state: LoadoutState, registry: [RegistryEntry]) -> [String] {
        let known = Set(registry.map(\.service))
        var order = state.order.filter { known.contains($0) }
        let remaining = known.subtracting(order).sorted()
        order.append(contentsOf: remaining)
        return order
    }

    private static func variantKey(service: String, variant: String) -> String {
        "\(service)\u{1f}:\(variant)"
    }

    private static func variableNamesIndex(
        registry: [RegistryEntry],
        catalog: KeychainCatalog
    ) -> [String: [String]] {
        var index: [String: [String]] = [:]
        for entry in registry {
            for variant in entry.variants {
                let key = variantKey(service: entry.service, variant: variant)
                index[key] = catalog.variableNames(service: entry.service, variant: variant)
            }
        }
        return index
    }

    private nonisolated static func buildExportPreview(
        catalog: KeychainCatalog,
        exportEngine: ExportEngine
    ) -> String {
        guard let result = try? exportEngine.export(catalog: catalog) else {
            return ""
        }
        var lines = result.lines
        for warning in result.warnings {
            lines.append("# \(warning)")
        }
        return lines.joined(separator: "\n")
    }

    private func presentAlert(title: String, message: String) {
        alert = LoadoutAlert(title: title, message: message)
    }
}