import Foundation

extension Notification.Name {
    /// Posted when the app should reload keychain/registry state (wake, unlock, etc.).
    static let loadoutRefreshRequested = Notification.Name("dev.loadout.app.refreshRequested")
}