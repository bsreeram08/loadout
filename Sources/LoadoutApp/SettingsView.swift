import SwiftUI

struct GeneralSettingsTab: View {
    @Bindable var model: LoadoutMenuModel

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.loginEnabled },
                    set: { _ in model.toggleLogin() }
                ))
            }

            Section("Collision order") {
                Text("When two services export the same variable, earlier services win.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(model.collisionOrder.enumerated()), id: \.element) { index, service in
                    HStack {
                        Text(service)
                        Spacer()
                        Button {
                            model.moveServiceUp(at: index)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(index == 0)
                        Button {
                            model.moveServiceDown(at: index)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(index == model.collisionOrder.count - 1)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PathsSettingsTab: View {
    let model: LoadoutMenuModel

    var body: some View {
        Form {
            Section("Storage") {
                LabeledContent("State file") {
                    Text(model.stateFilePath)
                        .textSelection(.enabled)
                        .font(.caption)
                }
                LabeledContent("Keychain") {
                    Text(model.keychainPath)
                        .textSelection(.enabled)
                        .font(.caption)
                }
                LabeledContent("CLI binary") {
                    Text(model.cliPath)
                        .textSelection(.enabled)
                        .font(.caption)
                }
            }

            Section {
                Button("Reveal config folder") {
                    model.openConfigFolder()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ExportSettingsTab: View {
    let model: LoadoutMenuModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active export preview")
                .font(.headline)

            Text(model.context?.summary.footerLabel ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)

            GlassCodePanel {
                ScrollView {
                    Text(model.exportPreview.isEmpty ? "# nothing selected" : model.exportPreview)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button("How to reload open terminals…") {
                model.showReloadHint()
            }
        }
        .padding()
    }
}

struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 12) {
            GlassIconBadge(systemImage: "slider.horizontal.3")
            Text(LoadoutAppInfo.name)
                .font(.title2)
            Text("Version \(LoadoutAppInfo.version)")
                .foregroundStyle(.secondary)
            Text("Per-service environment profiles for macOS terminals.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}