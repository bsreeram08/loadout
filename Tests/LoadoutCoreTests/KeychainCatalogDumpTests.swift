import XCTest
@testable import LoadoutCore

/// Verifies KeychainCatalog enumerates dedicated keychain items without reading secret data.
final class KeychainCatalogDumpTests: XCTestCase {
    private var harness: KeychainTestHarness!

    override func setUpWithError() throws {
        try super.setUpWithError()
        harness = try KeychainTestHarness()
    }

    override func tearDownWithError() throws {
        harness?.teardown()
        harness = nil
        try super.tearDownWithError()
    }

    func testCatalogIgnoresNonLoadoutItemsInDedicatedKeychain() throws {
        let store = KeychainStore()
        let service = harness.uniqueService("flt")
        try store.set(service: service, variant: "dev", variable: "ONLY", value: "1")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "add-generic-password",
            "-a", "noise",
            "-s", "not-loadout-prefix",
            "-w", "ignored",
            "-A",
            harness.keychainPath,
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let registry = try KeychainCatalog().registry()
        XCTAssertTrue(registry.contains { $0.service == service })
        XCTAssertFalse(registry.contains { $0.service == "not-loadout-prefix" })
        XCTAssertEqual(
            try store.get(service: service, variant: "dev", variable: "ONLY"),
            "1"
        )

        _ = try store.deleteService(service)
        try runSecurity([
            "delete-generic-password",
            "-s", "not-loadout-prefix",
            "-a", "noise",
            harness.keychainPath,
        ])
    }

    private func runSecurity(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LoadoutError.io("security failed (exit \(process.terminationStatus))")
        }
    }
}