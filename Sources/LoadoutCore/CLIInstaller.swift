import Foundation

public struct CLIInstaller: Sendable {
    public static let installRelativePath = ".local/bin/loadout"

    public static var installURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(installRelativePath)
    }

    public init() {}

    public func bundledCLIURL(bundle: Bundle = .main) -> URL? {
        if let auxiliary = bundle.url(forAuxiliaryExecutable: "loadout") {
            return auxiliary
        }
        if let resource = bundle.url(forResource: "loadout", withExtension: nil) {
            return resource
        }
        if let exec = bundle.executableURL {
            let sibling = exec.deletingLastPathComponent().appendingPathComponent("loadout")
            if FileManager.default.isExecutableFile(atPath: sibling.path) {
                return sibling
            }
        }
        return nil
    }

    @discardableResult
    public func installBundledCLIIfNeeded(bundle: Bundle = .main) throws -> Bool {
        guard let source = bundledCLIURL(bundle: bundle) else {
            return false
        }

        let destination = Self.installURL
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: destination.path),
           !shouldReplaceInstalledCLI(source: source, destination: destination)
        {
            return false
        }

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
        try Self.adHocSign(destination)
        return true
    }

    func shouldReplaceInstalledCLI(source: URL, destination: URL) -> Bool {
        guard let sourceAttributes = try? FileManager.default.attributesOfItem(atPath: source.path),
              let destinationAttributes = try? FileManager.default.attributesOfItem(atPath: destination.path),
              let sourceDate = sourceAttributes[.modificationDate] as? Date,
              let destinationDate = destinationAttributes[.modificationDate] as? Date
        else {
            return true
        }
        return sourceDate > destinationDate
    }

    private static func adHocSign(_ binary: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-s", "-", "--force", "--timestamp=none", binary.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LoadoutError.io("failed to codesign \(binary.path)")
        }
    }
}