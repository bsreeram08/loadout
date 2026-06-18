import Foundation

enum TestProcess {
    static func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func loadoutExecutable() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["LOADOUT_TEST_BINARY"],
           !override.isEmpty
        {
            return URL(fileURLWithPath: override)
        }

        for candidate in candidateURLs() {
            if isRunnableExecutable(at: candidate) {
                return candidate
            }
        }
        try buildLoadoutIfNeeded()
        for candidate in candidateURLs() {
            if isRunnableExecutable(at: candidate) {
                return candidate
            }
        }
        throw TestProcessError.loadoutBinaryNotFound(searched: candidateURLs().map(\.path))
    }

    private static func isRunnableExecutable(at url: URL) -> Bool {
        if FileManager.default.isExecutableFile(atPath: url.path) {
            return true
        }
        // XCTest sandboxes sometimes reject isExecutableFile for out-of-bundle binaries.
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else { return false }
        return FileManager.default.isReadableFile(atPath: url.path)
    }

    @discardableResult
    static func run(
        executable: URL,
        arguments: [String],
        extraEnvironment: [String: String] = [:]
    ) throws -> RunResult {
        let stdout = Pipe()
        let stderr = Pipe()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        var env = ProcessInfo.processInfo.environment
        for (key, value) in extraEnvironment {
            env[key] = value
        }
        process.environment = env
        try process.run()
        process.waitUntilExit()
        return RunResult(
            stdout: String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            stderr: String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            status: process.terminationStatus
        )
    }

    struct RunResult {
        let stdout: String
        let stderr: String
        let status: Int32
    }

    private static func candidateURLs() -> [URL] {
        let arch = ProcessInfo.processInfo.hostArchitecture
        var roots = [projectRoot()]
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if cwd != roots[0] {
            roots.append(cwd)
        }
        var candidates: [URL] = []
        for root in roots {
            for config in ["debug", "release"] {
                candidates.append(root.appendingPathComponent(".build/\(arch)-apple-macosx/\(config)/loadout"))
                candidates.append(root.appendingPathComponent(".build/\(config)/loadout"))
            }
        }
        return candidates
    }

    private static func buildLoadoutIfNeeded() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["build", "--product", "loadout"]
        process.currentDirectoryURL = projectRoot()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw TestProcessError.buildFailed(exitCode: process.terminationStatus)
        }
    }

    enum TestProcessError: Error, CustomStringConvertible {
        case loadoutBinaryNotFound(searched: [String])
        case buildFailed(exitCode: Int32)

        var description: String {
            switch self {
            case .loadoutBinaryNotFound(let searched):
                return "loadout binary not found — run `swift build --product loadout` first (searched: \(searched.joined(separator: ", ")))"
            case .buildFailed(let exitCode):
                return "swift build --product loadout failed (exit \(exitCode))"
            }
        }
    }
}

private extension ProcessInfo {
    var hostArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}