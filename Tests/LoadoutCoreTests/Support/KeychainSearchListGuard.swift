import Foundation
@testable import LoadoutCore

/// Saves and restores the user keychain search list around tests that mutate it.
final class KeychainSearchListGuard {
    private let saved: [String]
    private var restored = false

    init() throws {
        saved = try Self.readSearchList()
    }

    func restore() {
        guard !restored else { return }
        restored = true
        try? Self.restoreSearchList(saved)
    }

    deinit {
        restore()
    }

    static func ensureLoginKeychainOnly() throws {
        let login = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Keychains/login.keychain-db")
            .path
        try runSecurity(["list-keychains", "-d", "user", "-s", login])
    }

    private static func readSearchList() throws -> [String] {
        let output = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["list-keychains", "-d", "user"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LoadoutError.io("failed to read keychain search list for tests")
        }
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) }
            .filter { !$0.isEmpty }
    }

    private static func restoreSearchList(_ keychains: [String]) throws {
        guard !keychains.isEmpty else {
            try ensureLoginKeychainOnly()
            return
        }
        try runSecurity(["list-keychains", "-d", "user", "-s"] + keychains)
    }

    private static func runSecurity(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LoadoutError.io("security \(arguments.first ?? "") failed (exit \(process.terminationStatus))")
        }
    }
}