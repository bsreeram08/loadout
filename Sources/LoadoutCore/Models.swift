import Foundation

public struct LoadoutState: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var selection: [String: String]
    public var order: [String]
    public var updatedAt: Date

    public init(
        version: Int = currentVersion,
        selection: [String: String] = [:],
        order: [String] = [],
        updatedAt: Date = .now
    ) {
        self.version = version
        self.selection = selection
        self.order = order
        self.updatedAt = updatedAt
    }
}

public struct ServiceVariant: Hashable, Sendable {
    public let service: String
    public let variant: String

    public init(service: String, variant: String) {
        self.service = service
        self.variant = variant
    }
}

public struct RegistryEntry: Hashable, Sendable {
    public let service: String
    public let variants: [String]
    public let variableCounts: [String: Int]

    public init(service: String, variants: [String], variableCounts: [String: Int]) {
        self.service = service
        self.variants = variants
        self.variableCounts = variableCounts
    }
}

public struct ExportResult: Sendable {
    public let lines: [String]
    public let warnings: [String]

    public init(lines: [String], warnings: [String]) {
        self.lines = lines
        self.warnings = warnings
    }
}

public enum LoadoutError: Error, CustomStringConvertible {
    case invalidServiceName(String)
    case invalidVariantName(String)
    case invalidVariableName(String)
    case stateNotFound
    case keychain(OSStatus)
    case io(String)

    public var description: String {
        switch self {
        case .invalidServiceName(let name):
            return "invalid service name: \(name)"
        case .invalidVariantName(let name):
            return "invalid variant name: \(name)"
        case .invalidVariableName(let name):
            return "invalid variable name: \(name)"
        case .stateNotFound:
            return "state file not found (run loadout select first)"
        case .keychain(let status):
            return "keychain error: \(status)"
        case .io(let message):
            return message
        }
    }
}