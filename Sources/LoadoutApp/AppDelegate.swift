import AppKit
import LoadoutCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateDuplicateInstances()
        NSApp.setActivationPolicy(.accessory)

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
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        let myPID = ProcessInfo.processInfo.processIdentifier
        for app in NSWorkspace.shared.runningApplications where app.processIdentifier != myPID {
            guard app.bundleURL?.standardizedFileURL == bundleURL else { continue }
            app.terminate()
        }
    }
}