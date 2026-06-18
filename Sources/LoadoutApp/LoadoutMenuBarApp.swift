import AppKit
import SwiftUI

@main
struct LoadoutMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = LoadoutMenuModel()

    var body: some Scene {
        MenuBarExtra {
            LoadoutMenuView(model: model)
        } label: {
            MenuBarIconLabel(showsProdWarning: model.hasProdSelected)
        }
        .menuBarExtraStyle(.menu)

        Window("Loadout", id: "loadout") {
            LoadoutWindowView(model: model)
        }
        .defaultSize(width: 720, height: 520)
        .windowToolbarStyle(.unified)
        .commands {
            LoadoutCommands(model: model)
        }
    }
}

private struct LoadoutCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    var model: LoadoutMenuModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                Task { @MainActor in
                    model.preferredWindowTab = .settings
                    openWindow(id: "loadout")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(after: .appInfo) {
            Button("Open Loadout…") {
                Task { @MainActor in
                    model.preferredWindowTab = .services
                    openWindow(id: "loadout")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(replacing: .appTermination) {
            Button("Quit Loadout") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}