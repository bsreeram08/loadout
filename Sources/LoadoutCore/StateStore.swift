import Foundation

public struct StateStore: Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL = LoadoutPaths.stateFileURL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> LoadoutState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LoadoutState()
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(LoadoutState.self, from: data)
    }

    @discardableResult
    public func save(_ state: LoadoutState) throws -> LoadoutState {
        var next = state
        next.version = LoadoutState.currentVersion
        next.updatedAt = .now
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(next)
        try data.write(to: fileURL, options: .atomic)
        return next
    }

    public func select(service: String, variant: String) throws -> LoadoutState {
        try NameValidator.validateService(service)
        try NameValidator.validateVariant(variant)
        var state = try load()
        state.selection[service] = variant
        if !state.order.contains(service) {
            state.order.append(service)
            state.order.sort()
        }
        return try save(state)
    }

    public func deselect(service: String) throws -> LoadoutState {
        try NameValidator.validateService(service)
        var state = try load()
        state.selection.removeValue(forKey: service)
        return try save(state)
    }

    public func setOrder(_ order: [String]) throws -> LoadoutState {
        var state = try load()
        state.order = order
        return try save(state)
    }

    public func removeServiceReferences(_ service: String) throws -> LoadoutState {
        try NameValidator.validateService(service)
        var state = try load()
        state.selection.removeValue(forKey: service)
        state.order.removeAll { $0 == service }
        return try save(state)
    }
}