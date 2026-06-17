import Foundation
import Security

/// Dedicated Keychain for Loadout — empty password, `-A` items survive rebuilds without repair.
public enum LoadoutKeychain {
    public static let fileName = "loadout.keychain-db"

    public static var path: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Keychains/\(fileName)")
            .path
    }

    static var loginPath: String {
        KeychainAccess.loginKeychainPath
    }

    static func ensureReady() throws {
        if ProcessInfo.processInfo.environment["LOADOUT_SKIP_PARTITION"] == "1" {
            return
        }
        if !FileManager.default.fileExists(atPath: path) {
            try create()
        }
        try unlock()
        try setSearchList()
    }

    static func create() throws {
        try runSecurity(["create-keychain", "-p", "", path], allowFailure: true)
        try runSecurity(["set-keychain-settings", "-lut", "86400", path])
        try unlock()
        try setSearchList()
    }

    static func unlock() throws {
        try runSecurity(["unlock-keychain", "-p", "", path], allowFailure: true)
    }

    static func setSearchList() throws {
        try runSecurity(["list-keychains", "-d", "user", "-s", path, loginPath])
    }

    static func setLoginSearchList() throws {
        try runSecurity(["list-keychains", "-d", "user", "-s", loginPath])
    }

    static func withExclusiveSearchList<T>(_ keychain: String, _ body: () throws -> T) throws -> T {
        let previous = try currentSearchList()
        defer {
            try? runSecurity(["list-keychains", "-d", "user", "-s"] + previous, allowFailure: true)
        }
        try runSecurity(["list-keychains", "-d", "user", "-s", keychain])
        return try body()
    }

    private static func currentSearchList() throws -> [String] {
        let output = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["list-keychains", "-d", "user"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LoadoutError.io("failed to read keychain search list")
        }
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) }
            .filter { !$0.isEmpty }
    }

    /// Store with `-A` (any app) so rebuilds don't need ACL repair.
    static func storeAllowAny(service: String, account: String, value: String) throws {
        if ProcessInfo.processInfo.environment["LOADOUT_SKIP_PARTITION"] == "1" {
            try storeViaSecItem(service: service, account: account, value: value)
            return
        }

        try ensureReady()
        // `-U` (update) hangs on custom keychains; delete-then-add is reliable.
        try runSecurity([
            "delete-generic-password",
            "-s", service,
            "-a", account,
            path,
        ], allowFailure: true)

        let input = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "add-generic-password",
            "-a", account,
            "-s", service,
            "-A",
            path,
        ]
        process.standardInput = input
        process.standardOutput = FileHandle.nullDevice
        process.standardError = Pipe()
        try process.run()
        input.fileHandleForWriting.write(Data(value.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let err = (process.standardError as? Pipe)?
                .fileHandleForReading.readDataToEndOfFile()
            let detail = err.flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw LoadoutError.io(
                "failed to store \(service)/\(account) (exit \(process.terminationStatus)"
                    + (detail.isEmpty ? ")" : ": \(detail))")
            )
        }
    }

    static func readSecret(keychain: String, service: String, account: String) throws -> String? {
        let output = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "find-generic-password",
            "-s", service,
            "-a", account,
            "-w",
            keychain,
        ]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let value = String(data: data, encoding: .utf8) else { return nil }
        return value.trimmingCharacters(in: .newlines)
    }

    static func deleteFromLogin(service: String, account: String) throws {
        try delete(service: service, account: account, keychain: loginPath)
    }

    static func delete(service: String, account: String) throws {
        if ProcessInfo.processInfo.environment["LOADOUT_SKIP_PARTITION"] == "1" {
            try deleteViaSecItem(service: service, account: account)
            return
        }
        try ensureReady()
        try delete(service: service, account: account, keychain: path)
    }

    private static func delete(service: String, account: String, keychain: String) throws {
        try runSecurity([
            "delete-generic-password",
            "-s", service,
            "-a", account,
            keychain,
        ], allowFailure: true)
    }

    private static func deleteViaSecItem(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LoadoutError.keychain(status)
        }
    }

    private static func storeViaSecItem(service: String, account: String, value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw LoadoutError.keychain(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw LoadoutError.keychain(addStatus)
        }
    }

    private static func runSecurity(_ arguments: [String], allowFailure: Bool = false) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        if !allowFailure && process.terminationStatus != 0 {
            throw LoadoutError.io(
                "security \(arguments.first ?? "") failed (exit \(process.terminationStatus))"
            )
        }
    }
}