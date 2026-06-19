import AppKit
import LoadoutCore
import SwiftUI

private enum DeleteConfirmation: Identifiable {
    case variable(service: String, variant: String, name: String)
    case variant(service: String, variant: String)
    case service(String)

    var id: String {
        switch self {
        case .variable(let service, let variant, let name):
            return "var:\(service):\(variant):\(name)"
        case .variant(let service, let variant):
            return "variant:\(service):\(variant)"
        case .service(let service):
            return "service:\(service)"
        }
    }

    var title: String {
        switch self {
        case .variable(_, _, let name):
            return "Delete \(name)?"
        case .variant(_, let variant):
            return "Delete variant \(variant)?"
        case .service(let service):
            return "Delete \(service)?"
        }
    }

    var message: String {
        switch self {
        case .variable:
            return "This removes the variable from Keychain. It cannot be undone."
        case .variant:
            return "This removes every variable in the variant from Keychain."
        case .service:
            return "This removes the entire service from Keychain and clears its selection."
        }
    }
}

private struct ServiceVariantContext: Identifiable, Equatable {
    let service: String
    let variant: String

    var id: String { "\(service):\(variant)" }
}

private struct ServiceContext: Identifiable, Equatable {
    let service: String

    var id: String { service }
}

@MainActor
struct ManageView: View {
    @Bindable var model: LoadoutMenuModel
    @State private var draftVariant = ""
    @State private var addVariableContext: ServiceVariantContext?
    @State private var editVariableContext: EditVariableContext?
    @State private var showingAddService = false
    @State private var addVariantContext: ServiceContext?
    @State private var deleteConfirmation: DeleteConfirmation?

    private var servicesSubtitle: String {
        if let error = model.context?.errorMessage {
            return error
        }
        return model.context?.summary.footerLabel ?? ""
    }

    var body: some View {
        LoadoutSplitTabShell(
            title: "Services",
            subtitle: servicesSubtitle,
            actions: LoadoutTabActions(
                addTitle: "Add service",
                onAdd: { showingAddService = true },
                onRefresh: { model.refresh() }
            )
        ) {
            ScrollView {
                VStack(spacing: 6) {
                    if let registry = model.context?.registry, !registry.isEmpty {
                        ForEach(registry, id: \.service) { entry in
                            Button {
                                model.manageSelection = entry.service
                            } label: {
                                ManageServiceRow(
                                    service: entry.service,
                                    selectedVariant: model.selectedVariant(for: entry.service),
                                    isSelected: model.manageSelection == entry.service
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("No services — import from .zshrc or add one.")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } detail: {
            detailPane
        }
        .sheet(isPresented: $showingAddService) {
            AddServiceSheet(model: model)
        }
        .sheet(item: $addVariableContext) { context in
            SetVariableSheet(
                service: context.service,
                variant: context.variant,
                mode: .add,
                model: model
            )
        }
        .sheet(item: $editVariableContext) { context in
            SetVariableSheet(
                service: context.service,
                variant: context.variant,
                mode: .edit(name: context.name),
                model: model
            )
        }
        .sheet(item: $addVariantContext) { context in
            AddVariantSheet(service: context.service, model: model) { created in
                draftVariant = created
            }
        }
        .confirmationDialog(
            deleteConfirmation?.title ?? "Delete?",
            isPresented: Binding(
                get: { deleteConfirmation != nil },
                set: { if !$0 { deleteConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = deleteConfirmation {
                Button("Delete", role: .destructive) {
                    performDelete(target)
                    deleteConfirmation = nil
                }
            }
            Button("Cancel", role: .cancel) {
                deleteConfirmation = nil
            }
        } message: {
            if let target = deleteConfirmation {
                Text(target.message)
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let error = model.context?.errorMessage {
            LoadoutPlaceholderState(
                title: "Keychain error",
                message: error
            )
        } else if let service = model.manageSelection,
                  let entry = model.registryEntry(for: service)
        {
            ManageServiceDetail(
                entry: entry,
                selectedVariant: model.selectedVariant(for: service),
                draftVariant: draftVariantBinding(for: entry),
                onAddVariable: {
                    addVariableContext = ServiceVariantContext(
                        service: entry.service,
                        variant: resolvedDraftVariant(for: entry)
                    )
                },
                onAddVariant: {
                    addVariantContext = ServiceContext(service: entry.service)
                },
                onEditVariable: { name in
                    editVariableContext = EditVariableContext(
                        service: entry.service,
                        variant: resolvedDraftVariant(for: entry),
                        name: name
                    )
                },
                deleteConfirmation: $deleteConfirmation,
                model: model
            )
            .id(service)
        } else {
            LoadoutPlaceholderState(
                title: "Select a service",
                message: "Choose a service from the sidebar to manage variants and variables.",
                actionTitle: "Add service…",
                action: { showingAddService = true }
            )
        }
    }

    private func resolvedDraftVariant(for entry: RegistryEntry) -> String {
        if let selected = model.selectedVariant(for: entry.service),
           entry.variants.contains(selected)
        {
            return selected
        }
        if entry.variants.contains(draftVariant) {
            return draftVariant
        }
        return entry.variants.first ?? ""
    }

    private func draftVariantBinding(for entry: RegistryEntry) -> Binding<String> {
        Binding(
            get: { @MainActor in resolvedDraftVariant(for: entry) },
            set: { @MainActor in draftVariant = $0 }
        )
    }

    private func activeVariant(for service: String) -> String {
        guard let entry = model.registryEntry(for: service) else {
            return model.selectedVariant(for: service) ?? "prod"
        }
        let variant = resolvedDraftVariant(for: entry)
        return variant.isEmpty
            ? (model.selectedVariant(for: service) ?? entry.variants.first ?? "prod")
            : variant
    }

    private func performDelete(_ target: DeleteConfirmation) {
        switch target {
        case .variable(let service, let variant, let name):
            model.deleteVariable(service: service, variant: variant, name: name)
        case .variant(let service, let variant):
            model.deleteVariant(service: service, variant: variant)
        case .service(let service):
            model.deleteService(service)
        }
    }
}

private struct ManageServiceRow: View {
    let service: String
    let selectedVariant: String?
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(service)
                .fontWeight(isSelected ? .semibold : .regular)
            Spacer()
            if let selectedVariant {
                Text(selectedVariant)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Text("off")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.55) : .clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ManageServiceDetail: View {
    let entry: RegistryEntry
    let selectedVariant: String?
    @Binding var draftVariant: String
    let onAddVariable: () -> Void
    let onAddVariant: () -> Void
    let onEditVariable: (String) -> Void
    @Binding var deleteConfirmation: DeleteConfirmation?
    let model: LoadoutMenuModel

    private var detailSubtitle: String {
        if let selectedVariant {
            return "Exporting variant \(selectedVariant)"
        }
        return "Not included in export"
    }

    private var variableNames: [String] {
        model.variableNames(service: entry.service, variant: draftVariant)
    }

    private var isSelectedForExport: Bool {
        selectedVariant != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoadoutChrome.cardSpacing) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.service)
                            .font(.title3.weight(.semibold))
                        Text(detailSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                LoadoutCardSection(title: "Selection") {
                    if entry.variants.isEmpty {
                        Text("No variants stored for this service.")
                            .foregroundStyle(.secondary)
                    } else {
                        LoadoutRow {
                            Text("Variant")
                                .font(.body.weight(.medium))
                            Spacer()
                            Picker("Variant", selection: $draftVariant) {
                                ForEach(entry.variants, id: \.self) { variant in
                                    Text(variant).tag(variant)
                                }
                            }
                            .labelsHidden()
                            .onChange(of: draftVariant) { _, newValue in
                                Task { @MainActor in
                                    guard !newValue.isEmpty, isSelectedForExport else { return }
                                    model.select(service: entry.service, variant: newValue)
                                }
                            }
                        }

                        if isSelectedForExport {
                            Label("Changing the Variant updates the Selection immediately.", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Label(
                                "Browsing stored variables only. This Service is not part of the Active set yet.",
                                systemImage: "info.circle"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            LoadoutActionRow(
                                title: "Select \(draftVariant) for export",
                                subtitle: "Add this Service and Variant to the Active set used by new terminals.",
                                systemImage: "checkmark.circle",
                                isDisabled: draftVariant.isEmpty
                            ) {
                                model.select(service: entry.service, variant: draftVariant)
                            }
                        }
                    }

                    LoadoutRow {
                        Toggle(
                            "Include in Active set",
                            isOn: Binding(
                                get: { isSelectedForExport },
                                set: { active in
                                    if active {
                                        model.select(service: entry.service, variant: draftVariant)
                                    } else {
                                        model.deselect(service: entry.service)
                                    }
                                }
                            )
                        )
                    }

                    if draftVariant == "prod" {
                        Label("Prod variant — double-check before exporting", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                LoadoutCardSection(title: "Variants") {
                    ForEach(entry.variants, id: \.self) { variant in
                        LoadoutRow {
                            Text(variant)
                            Spacer()
                            Text("\(entry.variableCounts[variant] ?? 0) vars")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if entry.variants.count > 1 {
                                Button(role: .destructive) {
                                    deleteConfirmation = .variant(service: entry.service, variant: variant)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Delete variant")
                            }
                        }
                    }
                    Button("Add variant…", action: onAddVariant)
                }

                LoadoutCardSection(title: "Variables", subtitle: draftVariant) {
                    if variableNames.isEmpty {
                        Text("No variables stored for this variant.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(variableNames, id: \.self) { name in
                            VariableRow(
                                name: name,
                                service: entry.service,
                                variant: draftVariant,
                                model: model,
                                onEdit: { onEditVariable(name) },
                                onDelete: {
                                    deleteConfirmation = .variable(
                                        service: entry.service,
                                        variant: draftVariant,
                                        name: name
                                    )
                                }
                            )
                        }
                    }
                    Button("Add variable…", action: onAddVariable)
                }

                LoadoutCardSection(title: "Danger zone") {
                    Button("Delete service…", role: .destructive) {
                        deleteConfirmation = .service(entry.service)
                    }
                }
            }
        }
    }
}

private struct EditVariableContext: Identifiable, Equatable {
    let service: String
    let variant: String
    let name: String

    var id: String { "\(service):\(variant):\(name)" }
}

private struct VariableRow: View {
    let name: String
    let service: String
    let variant: String
    let model: LoadoutMenuModel
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isRevealed = false
    @State private var revealedValue: String?
    @State private var loadError: String?
    @State private var isLoading = false

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Button {
                    toggleReveal()
                } label: {
                    Image(systemName: revealIconName)
                }
                .buttonStyle(.borderless)
                .help(revealActionLabel)
                .accessibilityLabel(revealActionLabel)
                .accessibilityHint("Requires authentication")
                .disabled(isLoading)

                if isRevealed, revealedValue != nil {
                    Button(action: copyValue) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy value")
                    .accessibilityLabel("Copy value")
                }

                Button("Edit", action: onEdit)
                    .buttonStyle(.borderless)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete variable")
                .accessibilityLabel("Delete variable")
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body)
                Text(valueLabel)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(valueColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contextMenu {
            Button(revealActionLabel) { toggleReveal() }
            if isRevealed, revealedValue != nil {
                Button("Copy value", action: copyValue)
            }
            Button("Edit…", action: onEdit)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .onChange(of: variant) { _, _ in
            hideValue()
        }
    }

    private var valueLabel: String {
        if !isRevealed {
            return "••••••••"
        }
        if isLoading {
            return "Loading…"
        }
        if let loadError {
            return loadError
        }
        guard let revealedValue else {
            return "No value stored in Keychain."
        }
        if revealedValue.isEmpty {
            return "(empty value)"
        }
        return revealedValue
    }

    private var valueColor: Color {
        if loadError != nil {
            return .red
        }
        if !isRevealed {
            return Color(nsColor: .tertiaryLabelColor)
        }
        return .secondary
    }

    private var revealActionLabel: String {
        if isRevealed, loadError != nil, revealedValue == nil {
            return "Retry reveal"
        }
        return isRevealed ? "Hide value" : "Show value"
    }

    private var revealIconName: String {
        if isRevealed, loadError != nil, revealedValue == nil {
            return "arrow.clockwise"
        }
        return isRevealed ? "eye.slash" : "eye"
    }

    private func toggleReveal() {
        if isRevealed {
            if loadError != nil, revealedValue == nil {
                hideValue()
            } else {
                hideValue()
                return
            }
        }
        if revealedValue != nil {
            isRevealed = true
            return
        }

        isLoading = true
        loadError = nil
        Task {
            do {
                try await KeychainAuthenticator.authenticateForSecretAccess()
                let value = try await model.variableValue(
                    service: service,
                    variant: variant,
                    name: name
                )
                await MainActor.run {
                    bringLoadoutForward()
                    revealedValue = value ?? ""
                    if value == nil {
                        loadError = "Could not read value. Unlock the loadout keychain and try again."
                        isRevealed = false
                    } else {
                        isRevealed = true
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    bringLoadoutForward()
                    if KeychainAuthenticator.isUserCancellation(error) {
                        loadError = "Authentication cancelled. Retry reveal and authenticate to show this value."
                        isRevealed = true
                        revealedValue = nil
                    } else {
                        loadError = error.localizedDescription
                        isRevealed = true
                        revealedValue = nil
                    }
                    isLoading = false
                }
            }
        }
    }

    private func hideValue() {
        isRevealed = false
        revealedValue = nil
        loadError = nil
        isLoading = false
    }

    private func copyValue() {
        guard let revealedValue else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(revealedValue, forType: .string)
    }

    private func bringLoadoutForward() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows
            .first { $0.title == LoadoutAppInfo.name }
            .map { $0.makeKeyAndOrderFront(nil) }
    }
}
