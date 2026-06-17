import SwiftUI

struct AddServiceSheet: View {
    @ObservedObject var model: LoadoutMenuModel

    @Environment(\.dismiss) private var dismiss
    @State private var serviceName = ""
    @State private var variantName = "prod"
    @State private var variableName = ""
    @State private var variableValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add service")
                .font(.headline)

            Text("Creates a service with its first variable in Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Service name", text: $serviceName)
                .textFieldStyle(.roundedBorder)

            TextField("Variant name", text: $variantName)
                .textFieldStyle(.roundedBorder)

            TextField("Variable name", text: $variableName)
                .textFieldStyle(.roundedBorder)

            SecureField("Secret value", text: $variableValue)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    model.setVariable(
                        service: serviceName,
                        variant: variantName,
                        name: variableName,
                        value: variableValue
                    )
                    model.manageSelection = serviceName
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    serviceName.isEmpty
                        || variantName.isEmpty
                        || variableName.isEmpty
                        || variableValue.isEmpty
                )
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}