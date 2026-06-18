import Foundation

public struct ShellHookInstaller: Sendable {
    public static let zshrcOverrideEnvironmentKey = "LOADOUT_ZSHRC_PATH"
    public static let startMarker = "# >>> loadout shell hook >>>"
    public static let endMarker = "# <<< loadout shell hook <<<"

    public static var zshrcURL: URL {
        if let override = ProcessInfo.processInfo.environment[zshrcOverrideEnvironmentKey],
           !override.isEmpty
        {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc")
    }

    public init() {}

    public func isInstalled(fileURL: URL = Self.zshrcURL) -> Bool {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return false
        }
        return contents.contains(Self.startMarker)
            && contents.contains(Self.endMarker)
            && contents.contains(" export 2>/dev/null")
    }

    @discardableResult
    public func installOrUpdate(fileURL: URL = Self.zshrcURL) throws -> Bool {
        let fileManager = FileManager.default
        let block = Self.hookBlock
        let original: String
        if fileManager.fileExists(atPath: fileURL.path) {
            original = try String(contentsOf: fileURL, encoding: .utf8)
        } else {
            original = ""
        }
        let next: String

        if let start = original.range(of: Self.startMarker),
           let end = original.range(of: Self.endMarker, range: start.upperBound..<original.endIndex)
        {
            let blockRange = start.lowerBound..<end.upperBound
            next = original.replacingCharacters(in: blockRange, with: block)
        } else {
            let separator = original.isEmpty || original.hasSuffix("\n") ? "" : "\n"
            next = original + separator + "\n" + block + "\n"
        }

        guard next != original else { return false }
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try next.write(to: fileURL, atomically: true, encoding: .utf8)
        return true
    }

    public static var hookBlock: String {
        let cliPath = shellSingleQuoted(CLIInstaller.installURL.path)
        return """
        \(startMarker)
        if [ -x \(cliPath) ]; then
          eval "$(\(cliPath) export 2>/dev/null)"
          reloadenv() { eval "$(\(cliPath) export 2>/dev/null)"; }
        fi
        \(endMarker)
        """
    }

    public static func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
