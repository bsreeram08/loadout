import Foundation
import ServiceManagement

public enum LoginItemController: Sendable {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    public static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "enabled"
        case .requiresApproval:
            return "requires approval in System Settings"
        case .notRegistered:
            return "off"
        case .notFound:
            return "not available"
        @unknown default:
            return "unknown"
        }
    }
}