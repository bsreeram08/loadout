import SwiftUI

enum VariableSheetMode: Equatable {
    case add
    case edit(name: String)
}

struct SetVariableSheet: View {
    let service: String
    let variant: String
    let mode: VariableSheetMode
    @ObservedObject var model: LoadoutMenuModel

    @Environment(\.dismiss) private var dismiss
    @State private var variableName = ""
    @State private var variableValue = ""

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
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            Text("\(service) / \(variant)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isEditing {
                LabeledContent("Name", value: variableName)
            } else {
                TextField("Variable name", text: $variableName)
                    .textFieldStyle(.roundedBorder)
            }

            SecureField(isEditing ? "New secret value" : "Secret value", text: $variableValue)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(saveLabel) {
                    let name = isEditing ? variableName : variableName
                    model.setVariable(
                        service: service,
                        variant: variant,
                        name: name,
                        value: variableValue
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            if case .edit(let name) = mode {
                variableName = name
            }
        }
    }

    private var canSave: Bool {
        if isEditing {
            return !variableValue.isEmpty
        }
        return !variableName.isEmpty && !variableValue.isEmpty
    }
}