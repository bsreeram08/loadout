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
    @State private var searchText = ""
    @State private var addVariableContext: ServiceVariantContext?
    @State private var editVariableContext: EditVariableContext?
    @State private var showingAddService = false
    @State private var addVariantContext: ServiceContext?
    @State private var deleteConfirmation: DeleteConfirmation?

    var body: some View {
        VStack(spacing: 0) {
            ActiveSetStrip(
                model: model,
                onAdd: { showingAddService = true },
                onRefresh: { model.refresh(force: true) }
            )

            Divider()

            if model.context?.errorMessage != nil {
                detailPane
            } else if model.context?.registry.isEmpty == true {
                emptyCatalogState
            } else {
                HStack(spacing: 0) {
                    sidebar
                    Divider()
                    detailPane
                }
            }
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

    // MARK: Sidebar

    private var allEntries: [RegistryEntry] {
        model.context?.registry ?? []
    }

    private func isActive(_ service: String) -> Bool {
        model.selectedVariant(for: service) != nil
    }

    private var filteredEntries: [RegistryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return allEntries }
        return allEntries.filter { $0.service.lowercased().contains(query) }
    }

    private var activeEntries: [RegistryEntry] {
        filteredEntries.filter { isActive($0.service) }
            .sorted { $0.service < $1.service }
    }

    private var inactiveEntries: [RegistryEntry] {
        filteredEntries.filter { !isActive($0.service) }
            .sorted { $0.service < $1.service }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField("Search services", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            .padding(12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if !activeEntries.isEmpty {
                        sectionHeader("Active", count: activeEntries.count)
                        ForEach(activeEntries, id: \.service) { entry in
                            serviceRow(entry)
                        }
                    }
                    if !inactiveEntries.isEmpty {
                        sectionHeader("Inactive", count: inactiveEntries.count)
                        ForEach(inactiveEntries, id: \.service) { entry in
                            serviceRow(entry)
                        }
                    }
                    if filteredEntries.isEmpty {
                        Text("No matches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 252)
        .background(.quaternary.opacity(0.18))
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        Text("\(title.uppercased()) · \(count)")
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 9)
            .padding(.top, 12)
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func serviceRow(_ entry: RegistryEntry) -> some View {
        let active = isActive(entry.service)
        let isSelected = model.manageSelection == entry.service
        return Button {
            model.manageSelection = entry.service
        } label: {
            HStack(spacing: 9) {
                StatusDot(isActive: active)
                Text(entry.service)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(active ? .primary : .secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                VariantPill(variant: model.selectedVariant(for: entry.service))
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.5)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: Detail

    @ViewBuilder
    private var detailPane: some View {
        if let error = model.context?.errorMessage {
            LoadoutPlaceholderState(
                title: "Keychain error",
                message: error
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LoadoutPlaceholderState(
                title: "Select a service",
                message: "Choose a service from the sidebar to manage variants and variables.",
                actionTitle: "Add service…",
                action: { showingAddService = true }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyCatalogState: some View {
        LoadoutPlaceholderState(
            title: "No services yet",
            message: "Import from your .zshrc or add a service to start building per-service environment profiles.",
            actionTitle: "Add service…",
            action: { showingAddService = true }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - Active-set strip

private struct ActiveSetStrip: View {
    let model: LoadoutMenuModel
    let onAdd: () -> Void
    let onRefresh: () -> Void

    @State private var didCopy = false

    private var summary: SelectionSummary? { model.context?.summary }

    var body: some View {
        HStack(spacing: 10) {
            if let summary {
                (
                    Text("\(summary.selectedServiceCount)")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                        + Text(summary.selectedServiceCount == 1 ? " service active" : " services active")
                )
                .font(.system(size: 12.5))

                Text("·").foregroundStyle(.tertiary)

                Text("\(summary.selectedVariableCount) \(summary.selectedVariableCount == 1 ? "variable" : "variables")")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)

                if summary.hasProdSelected {
                    prodWarning
                }
            }

            Spacer(minLength: 8)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")

            Button(action: onAdd) {
                Label("Add service", systemImage: "plus")
            }
            .controlSize(.small)
            .glassButton()

            Button {
                Task {
                    let n = await model.copyExport()
                    guard n > 0 else { return }
                    didCopy = true
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    didCopy = false
                }
            } label: {
                Label(
                    didCopy ? "Copied" : "Copy export",
                    systemImage: didCopy ? "checkmark" : "doc.on.clipboard"
                )
            }
            .controlSize(.small)
            .glassProminentButton()
            .disabled((summary?.selectedServiceCount ?? 0) == 0)
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, LoadoutChrome.contentPadding)
        .padding(.vertical, 9)
    }

    private var prodWarning: some View {
        let name = model.sensitiveActiveService
        return Label(
            name.map { "\($0) · prod" } ?? "prod active",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.red)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Color.red.opacity(0.14), in: Capsule())
    }
}

// MARK: - Detail pane

private struct ManageServiceDetail: View {
    let entry: RegistryEntry
    let selectedVariant: String?
    @Binding var draftVariant: String
    let onAddVariable: () -> Void
    let onAddVariant: () -> Void
    let onEditVariable: (String) -> Void
    @Binding var deleteConfirmation: DeleteConfirmation?
    let model: LoadoutMenuModel

    private var isActive: Bool { selectedVariant != nil }

    private var variableNames: [String] {
        model.variableNames(service: entry.service, variant: draftVariant)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                variantSelector
                variablesSection
                manageSection
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.service)
                    .font(.system(size: 21, weight: .bold))
                subtitle
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Text("Active")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Toggle("", isOn: Binding(
                    get: { isActive },
                    set: { active in
                        if active {
                            model.select(service: entry.service, variant: draftVariant)
                        } else {
                            model.deselect(service: entry.service)
                        }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(draftVariant.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if let selectedVariant {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("Exporting variant ")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    + Text(selectedVariant)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(LoadoutVariantStyle.color(for: selectedVariant))
            }
        } else {
            Text("Not in the active set — browsing stored variables only.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Variant selector

    @ViewBuilder
    private var variantSelector: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Variant")
            if entry.variants.isEmpty {
                Text("No variants stored for this service.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Add variant…", action: onAddVariant)
                    .controlSize(.small)
            } else {
                GlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(entry.variants, id: \.self) { variant in
                            VariantSegment(
                                variant: variant,
                                count: entry.variableCounts[variant] ?? 0,
                                isViewing: draftVariant == variant,
                                isExporting: selectedVariant == variant
                            ) {
                                draftVariant = variant
                                if isActive {
                                    model.select(service: entry.service, variant: variant)
                                }
                            }
                        }
                        Button(action: onAddVariant) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 34, height: 46)
                                .foregroundStyle(.secondary)
                                .glassSurface(cornerRadius: 10)
                        }
                        .buttonStyle(.plain)
                        .help("Add variant")
                    }
                }
                if entry.variants.count > 1 {
                    Menu {
                        ForEach(entry.variants, id: \.self) { variant in
                            Button(role: .destructive) {
                                deleteConfirmation = .variant(service: entry.service, variant: variant)
                            } label: {
                                Label("Delete \(variant)…", systemImage: "trash")
                            }
                        }
                    } label: {
                        Label("Manage variants", systemImage: "slider.horizontal.3")
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Variables

    private var variablesSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Variables", trailing: draftVariant.isEmpty ? nil : draftVariant)
            VStack(spacing: 0) {
                HStack {
                    Text("\(variableNames.count) \(variableNames.count == 1 ? "variable" : "variables")")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("stored in loadout.keychain")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                Divider()

                if variableNames.isEmpty {
                    Text("No variables stored for this variant.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    ForEach(Array(variableNames.enumerated()), id: \.element) { index, name in
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if index < variableNames.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }

                Divider()
                Button(action: onAddVariable) {
                    Label("Add variable", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .disabled(draftVariant.isEmpty)
            }
            .glassSurface(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary.opacity(0.4), lineWidth: 0.5)
            )
        }
    }

    // MARK: Manage / danger

    private var manageSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Manage")
            HStack {
                Text("Removes \(entry.service) and all variants from Keychain.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Delete service…", role: .destructive) {
                    deleteConfirmation = .service(entry.service)
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.red.opacity(0.18), lineWidth: 0.5)
            )
        }
    }

    private func sectionLabel(_ title: String, trailing: String? = nil) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.tertiary)
            if let trailing {
                Text("· \(trailing)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(LoadoutVariantStyle.color(for: trailing))
            }
        }
        .padding(.leading, 2)
    }
}

private struct VariantSegment: View {
    let variant: String
    let count: Int
    let isViewing: Bool
    let isExporting: Bool
    let action: () -> Void

    var body: some View {
        let color = LoadoutVariantStyle.color(for: variant)
        Button(action: action) {
            VStack(spacing: 2) {
                Text(variant)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isViewing ? color : Color.primary)
                Text("\(count) \(count == 1 ? "var" : "vars")")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .segmentBackground(color: color, isViewing: isViewing)
            .overlay(alignment: .topTrailing) {
                if isExporting {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(color)
                        .padding(5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    /// Glass-backed variant segment: tinted interactive glass when viewing,
    /// plain glass otherwise (with material fallback pre-macOS 26).
    @ViewBuilder
    func segmentBackground(color: Color, isViewing: Bool) -> some View {
        if isViewing {
            glassTinted(color, cornerRadius: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        } else {
            glassSurface(cornerRadius: 10)
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
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .frame(width: 190, alignment: .leading)

            Text(valueLabel)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                iconButton(revealIconName, help: revealActionLabel, action: toggleReveal)
                    .disabled(isLoading)
                if isRevealed, revealedValue != nil {
                    iconButton("doc.on.doc", help: "Copy value", action: copyValue)
                }
                iconButton("pencil", help: "Edit", action: onEdit)
                iconButton("trash", help: "Delete variable", destructive: true, action: onDelete)
            }
            .opacity(isHovering || isRevealed ? 1 : 0.55)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
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

    private func iconButton(
        _ systemName: String,
        help: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12))
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(destructive ? Color.red.opacity(0.85) : Color.secondary)
        .help(help)
        .accessibilityLabel(help)
    }

    private var valueLabel: String {
        if !isRevealed {
            return "••••••••••••"
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
