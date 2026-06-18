import SwiftUI

struct SettingsTabView: View {
    @Bindable var model: LoadoutMenuModel
    @State private var section: SettingsSection = .general

    var body: some View {
        VStack(spacing: 0) {
            GlassSegmentedPicker(
                options: SettingsSection.allCases,
                selection: $section,
                label: \.title,
                icon: \.icon
            )
            .padding(.horizontal, LoadoutChrome.contentPadding)
            .padding(.vertical, 10)

            Divider()

            Group {
                switch section {
                case .general:
                    GeneralSettingsTab(model: model)
                case .storage:
                    PathsSettingsTab(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

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
        .padding(LoadoutChrome.contentPadding)
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
        .padding(LoadoutChrome.contentPadding)
    }
}

struct ExportSettingsTab: View {
    let model: LoadoutMenuModel

    var body: some View {
        LoadoutPanelScaffold {
            VStack(alignment: .leading, spacing: 4) {
                Text("Active export preview")
                    .font(.headline)
                Text(model.context?.summary.footerLabel ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                GlassCodePanel {
                    ScrollView {
                        Text(model.exportPreview.isEmpty ? "# nothing selected" : model.exportPreview)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                Button("How to reload open terminals…") {
                    model.showReloadHint()
                }
            }
        }
    }
}

struct AboutSettingsTab: View {
    var body: some View {
        LoadoutPlaceholderState(
            title: LoadoutAppInfo.name,
            message: "Version \(LoadoutAppInfo.version)\n\nPer-service environment profiles for macOS terminals."
        )
    }
}