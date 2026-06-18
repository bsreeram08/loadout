import SwiftUI

struct SettingsTabView: View {
    @Bindable var model: LoadoutMenuModel

    var body: some View {
        LoadoutTabShell(title: "Settings", subtitle: "Preferences and storage paths") {
            LoadoutTabContent {
                ScrollView {
                    VStack(alignment: .leading, spacing: LoadoutChrome.cardSpacing) {
                        LoadoutCardSection(title: "Startup") {
                            Toggle("Launch at login", isOn: Binding(
                                get: { model.loginEnabled },
                                set: { _ in model.toggleLogin() }
                            ))
                        }

                    LoadoutCardSection(
                        title: "Load after restart",
                        subtitle: "Start Loadout at login and make new terminals apply the current Active set automatically."
                    ) {
                        LoadoutRow {
                            Label(
                                model.loginEnabled ? "Login item enabled" : "Login item off",
                                systemImage: model.loginEnabled ? "checkmark.circle.fill" : "circle"
                            )
                            .foregroundStyle(model.loginEnabled ? .green : .secondary)

                            Spacer()

                            Label(
                                model.shellHookInstalled ? "Shell hook installed" : "Shell hook missing",
                                systemImage: model.shellHookInstalled ? "checkmark.circle.fill" : "circle"
                            )
                            .foregroundStyle(model.shellHookInstalled ? .green : .secondary)
                        }

                        Text("After setup, a system restart reopens Loadout and every new zsh terminal evaluates `loadout export` from \(model.shellHookPath).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        HStack {
                            Button(model.restartLoadingReady ? "Restart loading ready" : "Set up restart loading") {
                                model.setUpRestartLoading()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.restartLoadingReady)

                            if !model.shellHookInstalled {
                                Button("Install shell hook only") {
                                    model.installShellHook()
                                }
                            }
                        }
                    }

                    LoadoutCardSection(
                        title: "Collision order",
                        subtitle: "When two Services define the same variable, earlier Services win."
                    ) {
                        ForEach(Array(model.collisionOrder.enumerated()), id: \.element) { index, service in
                            LoadoutRow {
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

                    LoadoutCardSection(title: "Storage") {
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

                        LoadoutCardSection(title: "Actions") {
                            Button("Reveal config folder") {
                                model.openConfigFolder()
                            }
                        }
                    }
                }
            }
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

                    Text("New terminals load this Active set automatically. Already-open shells keep their old environment; run `reloadenv` there if you need to re-apply Loadout.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

struct AboutSettingsTab: View {
    var body: some View {
        LoadoutTabShell(title: "About", subtitle: "Loadout for macOS") {
            LoadoutTabContent {
                LoadoutCardSection(
                    title: LoadoutAppInfo.name,
                    subtitle: "Version \(LoadoutAppInfo.version)"
                ) {
                    HStack(spacing: 12) {
                        LoadoutMark(size: 44)
                        Text("Per-Service Variant selection for macOS terminals. Secrets stay in the Loadout Keychain; Export builds the Active set for new shells.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
