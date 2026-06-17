import AppKit
import LoadoutCore
import SwiftUI

struct LoadoutMenuView: View {
    @ObservedObject var model: LoadoutMenuModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            Text("Loadout")
                .foregroundStyle(.secondary)

            Divider()

            Button("Manage…") {
                openWindow(id: "manage")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Settings…") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            if let error = model.context?.errorMessage {
                Text("Keychain error — unlock and retry")
                    .foregroundStyle(.secondary)
                    .help(error)
                Divider()
            } else if model.context?.registry.isEmpty ?? true {
                Button("Import secrets…") {
                    model.showImportHint()
                }
                Divider()
            } else if let registry = model.context?.registry,
                      let state = model.context?.state
            {
                ForEach(registry, id: \.service) { entry in
                    ServiceVariantMenu(
                        entry: entry,
                        selected: state.selection[entry.service],
                        model: model
                    )
                }
                Divider()
            }

            Text(model.context?.summary.footerLabel ?? "Loading…")
                .foregroundStyle(.secondary)

            Button("Reload open terminals…") {
                model.showReloadHint()
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            model.refresh()
        }
    }
}

private struct ServiceVariantMenu: View {
    let entry: RegistryEntry
    let selected: String?
    @ObservedObject var model: LoadoutMenuModel

    private var statusLabel: String {
        guard let selected else { return "(off)" }
        if entry.variants.contains(selected) {
            return selected
        }
        return "\(selected) (missing)"
    }

    var body: some View {
        Menu("\(entry.service)  \(statusLabel)") {
            ForEach(entry.variants, id: \.self) { variant in
                Button {
                    model.select(service: entry.service, variant: variant)
                } label: {
                    Text(variantLabel(variant))
                }
            }

            if selected != nil {
                Divider()
                Button("Turn off") {
                    model.deselect(service: entry.service)
                }
            }
        }
    }

    private func variantLabel(_ variant: String) -> String {
        let check = variant == selected ? "✓ " : ""
        let count = entry.variableCounts[variant] ?? 0
        let noun = count == 1 ? "var" : "vars"
        return "\(check)\(variant) (\(count) \(noun))"
    }
}