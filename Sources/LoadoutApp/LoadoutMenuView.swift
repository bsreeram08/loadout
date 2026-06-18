import AppKit
import LoadoutCore
import SwiftUI

struct LoadoutMenuView: View {
    @Bindable var model: LoadoutMenuModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Text("Loadout")
                .foregroundStyle(.secondary)

            Divider()

            Button("Manage services…") {
                model.preferredWindowTab = .services
                openMainWindow()
            }

            Button("Settings…") {
                model.preferredWindowTab = .settings
                openMainWindow()
            }

            Divider()

            if let error = model.context?.errorMessage {
                Text("Keychain error — unlock and retry")
                    .foregroundStyle(.secondary)
                    .help(error)
                Divider()
            } else if model.context == nil {
                if model.isRefreshing {
                    Text("Loading services…")
                        .foregroundStyle(.secondary)
                } else {
                    Button("Retry loading…") {
                        model.refresh(force: true)
                    }
                }
                Divider()
            } else if model.context?.registry.isEmpty == true {
                Button("Import secrets…") {
                    model.showImportHint()
                }
                Divider()
            } else {
                activeSection
                Divider()
            }

            if model.hasProdSelected {
                Label("Prod variant active", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            if model.context == nil, model.isRefreshing {
                Text("Loading…")
                    .foregroundStyle(.secondary)
            } else {
                Text(statusLine)
                    .foregroundStyle(.secondary)
            }

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
            model.refreshIfStale()
        }
    }

    @ViewBuilder
    private var activeSection: some View {
        let active = model.activeMenuEntries()
        if active.isEmpty {
            Text("No services active")
                .foregroundStyle(.secondary)
        } else {
            ForEach(active) { item in
                if let entry = item.entry {
                    ServiceVariantMenu(
                        entry: entry,
                        selected: item.variant,
                        model: model
                    )
                } else {
                    MissingServiceMenu(
                        service: item.service,
                        variant: item.variant,
                        model: model
                    )
                }
            }
        }
    }

    private var statusLine: String {
        guard let context = model.context else { return "Couldn't load state" }
        let stored = context.registry.count
        let summary = context.summary
        if summary.selectedServiceCount == 0 {
            let noun = stored == 1 ? "service" : "services"
            return "\(stored) \(noun) stored, none active"
        }
        return summary.footerLabel
    }

    private func openMainWindow() {
        openWindow(id: "loadout")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct ServiceVariantMenu: View {
    let entry: RegistryEntry
    let selected: String?
    let model: LoadoutMenuModel

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

private struct MissingServiceMenu: View {
    let service: String
    let variant: String
    let model: LoadoutMenuModel

    var body: some View {
        Menu("\(service)  \(variant) (missing)") {
            Button("Turn off") {
                model.deselect(service: service)
            }
        }
    }
}