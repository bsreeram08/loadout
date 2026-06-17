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

struct ManageView: View {
    @ObservedObject var model: LoadoutMenuModel
    @State private var draftVariant = ""
    @State private var showingAddVariable = false
    @State private var editingVariable: EditingVariable?
    @State private var showingAddService = false
    @State private var showingAddVariant = false
    @State private var deleteConfirmation: DeleteConfirmation?

    var body: some View {
        NavigationSplitView {
            List(selection: $model.manageSelection) {
                if let registry = model.context?.registry, !registry.isEmpty {
                    ForEach(registry, id: \.service) { entry in
                        ManageServiceRow(
                            service: entry.service,
                            selectedVariant: model.selectedVariant(for: entry.service)
                        )
                        .tag(entry.service)
                    }
                } else {
                    Text("No services — import from .zshrc or add one.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            detailPane
        }
        .frame(minWidth: 520, minHeight: 360)
        .onAppear { model.refresh() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddService = true
                } label: {
                    Label("Add Service", systemImage: "plus")
                }
            }
            ToolbarItem {
                Button {
                    model.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showingAddService) {
            AddServiceSheet(model: model)
        }
        .sheet(isPresented: $showingAddVariable) {
            if let service = model.manageSelection {
                SetVariableSheet(
                    service: service,
                    variant: activeVariant(for: service),
                    mode: .add,
                    model: model
                )
            }
        }
        .sheet(item: $editingVariable) { item in
            if let service = model.manageSelection {
                SetVariableSheet(
                    service: service,
                    variant: activeVariant(for: service),
                    mode: .edit(name: item.name),
                    model: model
                )
            }
        }
        .sheet(isPresented: $showingAddVariant) {
            if let service = model.manageSelection {
                AddVariantSheet(service: service, model: model) { created in
                    draftVariant = created
                }
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
            VStack(spacing: 8) {
                Image(systemName: "lock.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Keychain error")
                    .font(.headline)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let service = model.manageSelection,
                  let entry = model.registryEntry(for: service)
        {
            ManageServiceDetail(
                entry: entry,
                selectedVariant: model.selectedVariant(for: service),
                draftVariant: $draftVariant,
                showingAddVariable: $showingAddVariable,
                showingAddVariant: $showingAddVariant,
                editingVariable: $editingVariable,
                deleteConfirmation: $deleteConfirmation,
                model: model
            )
            .onAppear { syncDraftVariant(service: service, entry: entry) }
            .onChange(of: service) { _ in syncDraftVariant(service: service, entry: entry) }
            .onChange(of: entry.variants) { _ in syncDraftVariant(service: service, entry: entry) }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "sidebar.left")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Select a service")
                    .font(.headline)
                Text("Choose a service to manage variants and variables.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Add service…") {
                    showingAddService = true
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func syncDraftVariant(service: String, entry: RegistryEntry) {
        if let selected = model.selectedVariant(for: service),
           entry.variants.contains(selected)
        {
            draftVariant = selected
        } else if entry.variants.contains(draftVariant) {
            return
        } else {
            draftVariant = entry.variants.first ?? ""
        }
    }

    private func activeVariant(for service: String) -> String {
        let entry = model.registryEntry(for: service)
        if entry?.variants.contains(draftVariant) == true {
            return draftVariant
        }
        return model.selectedVariant(for: service)
            ?? entry?.variants.first
            ?? "prod"
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

    var body: some View {
        HStack {
            Text(service)
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
    }
}

private struct ManageServiceDetail: View {
    let entry: RegistryEntry
    let selectedVariant: String?
    @Binding var draftVariant: String
    @Binding var showingAddVariable: Bool
    @Binding var showingAddVariant: Bool
    @Binding var editingVariable: EditingVariable?
    @Binding var deleteConfirmation: DeleteConfirmation?
    @ObservedObject var model: LoadoutMenuModel

    var body: some View {
        Form {
            Section("Selection") {
                Picker("Variant", selection: $draftVariant) {
                    ForEach(entry.variants, id: \.self) { variant in
                        Text(variant).tag(variant)
                    }
                }
                .onChange(of: draftVariant) { newValue in
                    guard !newValue.isEmpty else { return }
                    model.select(service: entry.service, variant: newValue)
                }

                Toggle(
                    "Active in export",
                    isOn: Binding(
                        get: { selectedVariant != nil },
                        set: { active in
                            if active {
                                model.select(service: entry.service, variant: draftVariant)
                            } else {
                                model.deselect(service: entry.service)
                            }
                        }
                    )
                )

                if draftVariant == "prod" {
                    Label("Prod variant — double-check before exporting", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Variants") {
                ForEach(entry.variants, id: \.self) { variant in
                    HStack {
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
                Button("Add variant…") {
                    showingAddVariant = true
                }
            }

            Section("Variables (\(draftVariant))") {
                let names = model.variableNames(service: entry.service, variant: draftVariant)
                if names.isEmpty {
                    Text("No variables stored for this variant.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(names, id: \.self) { name in
                        HStack {
                            Label(name, systemImage: "key")
                            Spacer()
                            Button("Edit") {
                                editingVariable = EditingVariable(name: name)
                            }
                            .buttonStyle(.borderless)
                            Button(role: .destructive) {
                                deleteConfirmation = .variable(
                                    service: entry.service,
                                    variant: draftVariant,
                                    name: name
                                )
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .contextMenu {
                            Button("Edit…") { editingVariable = EditingVariable(name: name) }
                            Button("Delete", role: .destructive) {
                                deleteConfirmation = .variable(
                                    service: entry.service,
                                    variant: draftVariant,
                                    name: name
                                )
                            }
                        }
                    }
                }
                Button("Add variable…") {
                    showingAddVariable = true
                }
            }

            Section {
                Button("Delete service…", role: .destructive) {
                    deleteConfirmation = .service(entry.service)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(entry.service)
    }
}

private struct EditingVariable: Identifiable {
    let name: String
    var id: String { name }
}