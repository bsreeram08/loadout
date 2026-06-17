import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: LoadoutMenuModel

    var body: some View {
        TabView {
            GeneralSettingsTab(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }

            PathsSettingsTab(model: model)
                .tabItem { Label("Paths", systemImage: "folder") }

            ExportSettingsTab(model: model)
                .tabItem { Label("Export", systemImage: "terminal") }

            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 360)
        .onAppear { model.refresh() }
    }
}

private struct GeneralSettingsTab: View {
    @ObservedObject var model: LoadoutMenuModel

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

private struct PathsSettingsTab: View {
    @ObservedObject var model: LoadoutMenuModel

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

private struct ExportSettingsTab: View {
    @ObservedObject var model: LoadoutMenuModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active export preview")
                .font(.headline)

            Text(model.context?.summary.footerLabel ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(model.exportPreview.isEmpty ? "# nothing selected" : model.exportPreview)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2))
            }

            Button("How to reload open terminals…") {
                model.showReloadHint()
            }
        }
        .padding()
    }
}

private struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
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