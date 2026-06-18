import Foundation
import Security

/// Dedicated Keychain for Loadout — empty password, `-A` items survive rebuilds without repair.
public enum LoadoutKeychain {
    private static let blockingQueueKey = DispatchSpecificKey<UInt8>()
    private static let blockingQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "dev.loadout.keychain.blocking", qos: .userInitiated)
        queue.setSpecific(key: blockingQueueKey, value: 1)
        return queue
    }()

    public static let fileName = "loadout.keychain-db"

    public static var path: String {
        if let override = ProcessInfo.processInfo.environment["LOADOUT_KEYCHAIN_PATH"],
           !override.isEmpty
        {
            return override
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Keychains/\(fileName)")
            .path
    }

    static var loginPath: String {
        KeychainAccess.loginKeychainPath
    }

    static func ensureReady() throws {
        try withBlocking {
            try ensureReadyOnBlockingQueue()
        }
    }

    private static func ensureReadyOnBlockingQueue() throws {
        if ProcessInfo.processInfo.environment["LOADOUT_SKIP_PARTITION"] == "1" {
            return
        }
        if !FileManager.default.fileExists(atPath: path) {
            try createOnBlockingQueue()
            return
        }
        try unlockOnBlockingQueue()
        try setSearchListOnBlockingQueue()
    }

    static func create() throws {
        try withBlocking { try createOnBlockingQueue() }
    }

    private static func createOnBlockingQueue() throws {
        try runSecurityOnBlockingQueue(["create-keychain", "-p", "", path], allowFailure: true)
        try runSecurityOnBlockingQueue(["set-keychain-settings", "-lut", "86400", path])
        try unlockOnBlockingQueue()
        try setSearchListOnBlockingQueue()
    }

    static func unlock() throws {
        try withBlocking { try unlockOnBlockingQueue() }
    }

    private static func unlockOnBlockingQueue() throws {
        try runSecurityOnBlockingQueue(["unlock-keychain", "-p", "", path], allowFailure: true)
    }

    static func setSearchList() throws {
        try withBlocking { try setSearchListOnBlockingQueue() }
    }

    private static func setSearchListOnBlockingQueue() throws {
        try runSecurityOnBlockingQueue(["list-keychains", "-d", "user", "-s", path, loginPath])
    }

    static func setLoginSearchList() throws {
        try withBlocking {
            try runSecurityOnBlockingQueue(["list-keychains", "-d", "user", "-s", loginPath])
        }
    }

    static func withExclusiveSearchList<T>(_ keychain: String, _ body: () throws -> T) throws -> T {
        try withBlocking {
            let previous = try currentSearchListOnBlockingQueue()
            defer {
                try? runSecurityOnBlockingQueue(
                    ["list-keychains", "-d", "user", "-s"] + previous,
                    allowFailure: true
                )
            }
            try runSecurityOnBlockingQueue(["list-keychains", "-d", "user", "-s", keychain])
            return try body()
        }
    }

    static func dumpKeychain(_ keychainPath: String) throws -> String {
        try withBlocking {
            let output = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            process.arguments = ["dump-keychain", "-d", keychainPath]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return ""
            }
            return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        }
    }

    private static func currentSearchListOnBlockingQueue() throws -> [String] {
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

        try withBlocking {
            try ensureReadyOnBlockingQueue()
            // `-U` (update) hangs on custom keychains; delete-then-add is reliable.
            try runSecurityOnBlockingQueue([
                "delete-generic-password",
                "-s", service,
                "-a", account,
                path,
            ], allowFailure: true)

            let stderr = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            // Pass -w explicitly. Stdin after run() races: security reads empty password.
            process.arguments = [
                "add-generic-password",
                "-a", account,
                "-s", service,
                "-w", value,
                "-A",
                path,
            ]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = stderr
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let detail = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw LoadoutError.io(
                    "failed to store \(service)/\(account) (exit \(process.terminationStatus)"
                        + (detail.isEmpty ? ")" : ": \(detail))")
                )
            }

            guard let readBack = try readSecretOnBlockingQueue(keychain: path, service: service, account: account),
                  readBack == value
            else {
                throw LoadoutError.io(
                    "read-back verification failed for \(service)/\(account) — stored data mismatch"
                )
            }
        }
    }

    static func readSecret(keychain: String, service: String, account: String) throws -> String? {
        try withBlocking {
            try readSecretOnBlockingQueue(keychain: keychain, service: service, account: account)
        }
    }

    private static func readSecretOnBlockingQueue(
        keychain: String,
        service: String,
        account: String
    ) throws -> String? {
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
        try withBlocking {
            try deleteOnBlockingQueue(service: service, account: account, keychain: loginPath)
        }
    }

    static func delete(service: String, account: String) throws {
        if ProcessInfo.processInfo.environment["LOADOUT_SKIP_PARTITION"] == "1" {
            try deleteViaSecItem(service: service, account: account)
            return
        }
        try withBlocking {
            try ensureReadyOnBlockingQueue()
            try deleteOnBlockingQueue(service: service, account: account, keychain: path)
        }
    }

    private static func deleteOnBlockingQueue(service: String, account: String, keychain: String) throws {
        try runSecurityOnBlockingQueue([
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
        try withBlocking {
            try runSecurityOnBlockingQueue(arguments, allowFailure: allowFailure)
        }
    }

    private static func runSecurityOnBlockingQueue(
        _ arguments: [String],
        allowFailure: Bool = false
    ) throws {
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

    private static func withBlocking<T>(_ body: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: blockingQueueKey) != nil {
            return try body()
        }
        return try blockingQueue.sync(execute: body)
    }
}