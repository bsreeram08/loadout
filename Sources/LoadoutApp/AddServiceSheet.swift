import SwiftUI

struct AddServiceSheet: View {
    @Bindable var model: LoadoutMenuModel

    @Environment(\.dismiss) private var dismiss
    @State private var serviceName = ""
    @State private var variantName = "prod"
    @State private var variableName = ""
    @State private var variableValue = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Service name", text: $serviceName)
                    TextField("Variant name", text: $variantName)
                    TextField("Variable name", text: $variableName)
                    SecureField("Secret value", text: $variableValue)
                } footer: {
                    Text("Creates a service with its first variable in Keychain.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add service")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
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
                    .disabled(
                        serviceName.isEmpty
                            || variantName.isEmpty
                            || variableName.isEmpty
                            || variableValue.isEmpty
                    )
                }
            }
        }
        .frame(width: 420, height: 300)
    }
}