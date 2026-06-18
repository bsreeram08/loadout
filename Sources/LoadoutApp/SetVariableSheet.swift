import LoadoutCore
import SwiftUI

enum VariableSheetMode: Equatable {
    case add
    case edit(name: String)
}

struct SetVariableSheet: View {
    let service: String
    let variant: String
    let mode: VariableSheetMode
    let model: LoadoutMenuModel

    @Environment(\.dismiss) private var dismiss
    @State private var variableName = ""
    @State private var variableValue = ""
    @State private var loadError: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        isEditing ? "Edit variable" : "Add variable"
    }

    private var saveLabel: String {
        isEditing ? "Update" : "Save"
    }

    var body: some View {
        NavigationStack {
            Form {
                if let loadError {
                    Section {
                        Text(loadError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    if isEditing {
                        LabeledContent("Name", value: variableName)
                    } else {
                        TextField("Variable name", text: $variableName)
                    }

                    SecureField(isEditing ? "New secret value" : "Secret value", text: $variableValue)
                } footer: {
                    Text("\(service) / \(variant)")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveLabel) {
                        model.setVariable(
                            service: service,
                            variant: variant,
                            name: variableName,
                            value: variableValue
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .frame(width: 400, height: 260)
        .task(id: taskID) {
            await loadExistingValue()
        }
    }

    private var taskID: String {
        "\(service):\(variant):\(mode)"
    }

    private var canSave: Bool {
        if isEditing {
            return !variableValue.isEmpty
        }
        return !variableName.isEmpty && !variableValue.isEmpty
    }

    private func loadExistingValue() async {
        guard case .edit(let name) = mode else { return }
        variableName = name
        loadError = nil
        do {
            try await KeychainAuthenticator.authenticateForSecretAccess()
            if let value = try await model.variableValue(service: service, variant: variant, name: name) {
                variableValue = value
            }
        } catch {
            if KeychainAuthenticator.isUserCancellation(error) {
                loadError = "Authentication cancelled. Retry loading the current value, or enter a new secret value to overwrite it."
            } else {
                loadError = error.localizedDescription
            }
        }
    }
}
