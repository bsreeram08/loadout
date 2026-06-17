import SwiftUI

@main
struct LoadoutMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = LoadoutMenuModel()

    var body: some Scene {
        MenuBarExtra {
            LoadoutMenuView(model: model)
        } label: {
            MenuBarIconLabel()
        }
        .menuBarExtraStyle(.menu)

        Window("Manage Loadout", id: "manage") {
            ManageView(model: model)
        }
        .defaultSize(width: 560, height: 400)

        Settings {
            SettingsView(model: model)
        }
    }
}