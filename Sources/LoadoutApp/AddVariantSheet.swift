import SwiftUI

struct AddVariantSheet: View {
    let service: String
    @ObservedObject var model: LoadoutMenuModel
    var onCreated: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var variantName = ""
    @State private var variableName = ""
    @State private var variableValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add variant")
                .font(.headline)

            Text("\(service) — variants need at least one variable.")
                .font(.caption)
                .foregroundStyle(.secondary)

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
                        service: service,
                        variant: variantName,
                        name: variableName,
                        value: variableValue
                    )
                    onCreated(variantName)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    variantName.isEmpty
                        || variableName.isEmpty
                        || variableValue.isEmpty
                )
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}