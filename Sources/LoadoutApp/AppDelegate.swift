import AppKit
import LoadoutCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateDuplicateInstances()
        NSApp.setActivationPolicy(.accessory)
        observeSystemRefreshTriggers()

        Task.detached(priority: .utility) {
            do {
                _ = try CLIInstaller().installBundledCLIIfNeeded()
            } catch {
                NSLog("loadout: CLI install failed: \(error)")
            }
        }

        NSLog("loadout: MenuBarExtra app launched")
    }

    private func terminateDuplicateInstances() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        for app in NSWorkspace.shared.runningApplications where app.processIdentifier != myPID {
            guard isLoadoutInstance(app) else { continue }
            NSLog(
                "loadout: terminating duplicate instance pid=\(app.processIdentifier) bundle=\(app.bundleURL?.path ?? "nil")"
            )
            app.terminate()
        }
    }

    private func observeSystemRefreshTriggers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            NotificationCenter.default.post(name: .loadoutRefreshRequested, object: nil)
        }
    }

    private func isLoadoutInstance(_ app: NSRunningApplication) -> Bool {
        if app.bundleIdentifier == LoadoutAppInfo.bundleIdentifier {
            return true
        }
        if app.executableURL?.lastPathComponent == "LoadoutApp" {
            return true
        }
        if app.bundleURL?.lastPathComponent == "Loadout.app" {
            return true
        }
        return false
    }
}