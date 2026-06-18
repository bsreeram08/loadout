import SwiftUI

struct SettingsTabView: View {
    @Bindable var model: LoadoutMenuModel
    @State private var section: SettingsSection = .general

    var body: some View {
        LoadoutSplitTabShell(title: "Settings", subtitle: "Preferences and storage paths") {
            List(selection: $section) {
                ForEach(SettingsSection.allCases) { item in
                    Label(item.title, systemImage: item.icon)
                        .tag(item)
                }
            }
        } detail: {
            switch section {
            case .general:
                GeneralSettingsTab(model: model)
            case .storage:
                PathsSettingsTab(model: model)
            }
        }
    }
}

struct GeneralSettingsTab: View {
    @Bindable var model: LoadoutMenuModel

    var body: some View {
        LoadoutTabContent {
            LoadoutGroupedForm {
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
            .padding(LoadoutChrome.contentPadding)
        }
    }
}

struct PathsSettingsTab: View {
    let model: LoadoutMenuModel

    var body: some View {
        LoadoutTabContent {
            LoadoutGroupedForm {
                Section("Storage") {
                    LabeledContent("State file") {
                        Text(model.stateFilePath)
                            .textSelection(.enabled)
                            .font(.system(.caption, design: .monospaced))
                    }
                    LabeledContent("Keychain") {
                        Text(model.keychainPath)
                            .textSelection(.enabled)
                            .font(.system(.caption, design: .monospaced))
                    }
                    LabeledContent("CLI binary") {
                        Text(model.cliPath)
                            .textSelection(.enabled)
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                Section {
                    Button("Reveal config folder") {
                        model.openConfigFolder()
                    }
                }
            }
            .padding(LoadoutChrome.contentPadding)
        }
    }
}

struct ExportSettingsTab: View {
    let model: LoadoutMenuModel

    var body: some View {
        LoadoutTabShell(
            title: "Export preview",
            subtitle: model.context?.summary.footerLabel
        ) {
            LoadoutTabContent {
                VStack(alignment: .leading, spacing: 12) {
                    LoadoutCodePanel {
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
                .padding(LoadoutChrome.contentPadding)
            }
        }
    }
}

struct AboutSettingsTab: View {
    var body: some View {
        LoadoutTabShell(title: "About", subtitle: "Loadout for macOS") {
            LoadoutPlaceholderState(
                title: LoadoutAppInfo.name,
                message: "Version \(LoadoutAppInfo.version)\n\nPer-service environment profiles for macOS terminals."
            )
        }
    }
}