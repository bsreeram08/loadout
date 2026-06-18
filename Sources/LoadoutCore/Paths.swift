import Foundation

public enum LoadoutPaths {
    public static let configDirectoryName = "loadout"
    public static let stateFileName = "state.json"
    public static let keychainServicePrefix = "loadout:"

    public static var configDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent(configDirectoryName, isDirectory: true)
    }

    public static var stateFileURL: URL {
        if let override = ProcessInfo.processInfo.environment["LOADOUT_STATE_PATH"],
           !override.isEmpty
        {
            return URL(fileURLWithPath: override)
        }
        return configDirectory.appendingPathComponent(stateFileName)
    }

    public static func keychainService(service: String, variant: String) -> String {
        "\(keychainServicePrefix)\(service):\(variant)"
    }

    public static func parseKeychainService(_ serviceAttr: String) -> ServiceVariant? {
        guard serviceAttr.hasPrefix(keychainServicePrefix) else { return nil }
        let remainder = String(serviceAttr.dropFirst(keychainServicePrefix.count))
        guard let separator = remainder.lastIndex(of: ":") else { return nil }
        let service = String(remainder[..<separator])
        let variant = String(remainder[remainder.index(after: separator)...])
        guard !service.isEmpty, !variant.isEmpty else { return nil }
        return ServiceVariant(service: service, variant: variant)
    }
}