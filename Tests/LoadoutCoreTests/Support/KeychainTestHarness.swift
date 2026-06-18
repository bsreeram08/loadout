import Foundation
@testable import LoadoutCore

/// Isolated dedicated keychain for integration tests — exercises the real `security` CLI write path.
final class KeychainTestHarness {
    let keychainPath: String
    let stateFilePath: String
    private let searchListGuard: KeychainSearchListGuard
    private var tornDown = false

    init() throws {
        let id = UUID().uuidString
        let temp = FileManager.default.temporaryDirectory
        keychainPath = temp.appendingPathComponent("loadout-test-\(id).keychain-db").path
        stateFilePath = temp.appendingPathComponent("loadout-test-\(id)-state.json").path

        searchListGuard = try KeychainSearchListGuard()
        unsetenv("LOADOUT_SKIP_PARTITION")
        setenv("LOADOUT_KEYCHAIN_PATH", keychainPath, 1)
        setenv("LOADOUT_STATE_PATH", stateFilePath, 1)

        try? FileManager.default.removeItem(atPath: keychainPath)
        try? FileManager.default.removeItem(atPath: stateFilePath)
        try LoadoutKeychain.create()
    }

    deinit {
        teardown()
    }

    func teardown() {
        guard !tornDown else { return }
        tornDown = true
        unsetenv("LOADOUT_KEYCHAIN_PATH")
        unsetenv("LOADOUT_STATE_PATH")
        searchListGuard.restore()
        try? Self.deleteKeychain(at: keychainPath)
        try? FileManager.default.removeItem(atPath: stateFilePath)
    }

    func uniqueService(_ label: String) -> String {
        "t\(label)\(UUID().uuidString.prefix(6).lowercased())"
    }

    private static func deleteKeychain(at path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["delete-keychain", path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }
}