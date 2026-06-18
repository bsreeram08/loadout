import SwiftUI

struct AddVariantSheet: View {
    let service: String
    let model: LoadoutMenuModel
    var onCreated: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var variantName = ""
    @State private var variableName = ""
    @State private var variableValue = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Variant name", text: $variantName)
                    TextField("Variable name", text: $variableName)
                    SecureField("Secret value", text: $variableValue)
                } footer: {
                    Text("\(service) — variants need at least one variable.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add variant")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        model.setVariable(
                            service: service,
                            variant: variantName,
                            name: variableName,
                            value: variableValue
                        )
                        onCreated(variantName)
                        dismiss()
                    }
                    .disabled(
                        variantName.isEmpty
                            || variableName.isEmpty
                            || variableValue.isEmpty
                    )
                }
            }
        }
        .frame(width: 420, height: 280)
    }
}