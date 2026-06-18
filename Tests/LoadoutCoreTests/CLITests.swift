import XCTest
@testable import LoadoutCore

/// End-to-end CLI tests via subprocess — catches wiring bugs between ArgumentParser and KeychainStore.
final class CLITests: XCTestCase {
    private var harness: KeychainTestHarness!
    private var loadout: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        harness = try KeychainTestHarness()
        loadout = try TestProcess.loadoutExecutable()
    }

    override func tearDownWithError() throws {
        harness?.teardown()
        harness = nil
        loadout = nil
        try super.tearDownWithError()
    }

    private var testEnv: [String: String] {
        [
            "LOADOUT_KEYCHAIN_PATH": harness.keychainPath,
            "LOADOUT_STATE_PATH": harness.stateFilePath,
        ]
    }

    func testVersionFlag() throws {
        let result = try TestProcess.run(executable: loadout, arguments: ["--version"], extraEnvironment: testEnv)
        XCTAssertEqual(result.status, 0)
        XCTAssertTrue(result.stdout.contains(LoadoutVersion.current), result.stdout)
    }

    func testSetSelectExportRoundTrip() throws {
        let service = harness.uniqueService("cli")
        let set = try TestProcess.run(
            executable: loadout,
            arguments: ["set", service, "local", "CLI_KEY", "cli-secret"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(set.status, 0, set.stderr)
        XCTAssertTrue(set.stdout.contains("stored"), set.stdout)

        let select = try TestProcess.run(
            executable: loadout,
            arguments: ["select", service, "local"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(select.status, 0, select.stderr)

        let export = try TestProcess.run(
            executable: loadout,
            arguments: ["export"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(export.status, 0, export.stderr)
        XCTAssertTrue(
            export.stdout.contains("export CLI_KEY=") && export.stdout.contains("cli-secret"),
            export.stdout
        )

        let unset = try TestProcess.run(
            executable: loadout,
            arguments: ["unset", service, "--all"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(unset.status, 0, unset.stderr)
    }

    func testDeselectRemovesServiceFromSelection() throws {
        let service = harness.uniqueService("desel")
        XCTAssertEqual(
            try TestProcess.run(
                executable: loadout,
                arguments: ["set", service, "local", "K", "v"],
                extraEnvironment: testEnv
            ).status,
            0
        )
        XCTAssertEqual(
            try TestProcess.run(
                executable: loadout,
                arguments: ["select", service, "local"],
                extraEnvironment: testEnv
            ).status,
            0
        )

        let deselect = try TestProcess.run(
            executable: loadout,
            arguments: ["deselect", service],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(deselect.status, 0, deselect.stderr)
        XCTAssertTrue(deselect.stdout.contains("deselected"), deselect.stdout)

        let export = try TestProcess.run(
            executable: loadout,
            arguments: ["export"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(export.status, 0, export.stderr)
        XCTAssertTrue(export.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, export.stdout)

        _ = try TestProcess.run(
            executable: loadout,
            arguments: ["unset", service, "--all"],
            extraEnvironment: testEnv
        )
    }

    func testOrderChangesExportPrecedence() throws {
        let first = harness.uniqueService("ord1")
        let second = harness.uniqueService("ord2")

        for (service, value) in [(first, "first-wins"), (second, "second-loses")] {
            XCTAssertEqual(
                try TestProcess.run(
                    executable: loadout,
                    arguments: ["set", service, "local", "PREC", value],
                    extraEnvironment: testEnv
                ).status,
                0
            )
            XCTAssertEqual(
                try TestProcess.run(
                    executable: loadout,
                    arguments: ["select", service, "local"],
                    extraEnvironment: testEnv
                ).status,
                0
            )
        }

        let order = try TestProcess.run(
            executable: loadout,
            arguments: ["order", first, second],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(order.status, 0, order.stderr)

        let export = try TestProcess.run(
            executable: loadout,
            arguments: ["export"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(export.status, 0, export.stderr)
        XCTAssertTrue(export.stdout.contains("first-wins"), export.stdout)
        XCTAssertFalse(export.stdout.contains("second-loses"), export.stdout)

        _ = try TestProcess.run(executable: loadout, arguments: ["unset", first, "--all"], extraEnvironment: testEnv)
        _ = try TestProcess.run(executable: loadout, arguments: ["unset", second, "--all"], extraEnvironment: testEnv)
    }

    func testListAndStatusShowStoredRegistry() throws {
        let service = harness.uniqueService("lst")
        XCTAssertEqual(
            try TestProcess.run(
                executable: loadout,
                arguments: ["set", service, "prod", "LIST_KEY", "list-value"],
                extraEnvironment: testEnv
            ).status,
            0
        )
        XCTAssertEqual(
            try TestProcess.run(
                executable: loadout,
                arguments: ["select", service, "prod"],
                extraEnvironment: testEnv
            ).status,
            0
        )

        let list = try TestProcess.run(
            executable: loadout,
            arguments: ["list"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(list.status, 0, list.stderr)
        XCTAssertTrue(list.stdout.contains(service) && list.stdout.contains("prod"), list.stdout)

        let status = try TestProcess.run(
            executable: loadout,
            arguments: ["status"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(status.status, 0, status.stderr)
        XCTAssertTrue(status.stdout.contains("\(service) → prod"), status.stdout)
        XCTAssertTrue(status.stdout.contains(harness.keychainPath), status.stdout)
        XCTAssertTrue(status.stdout.contains(harness.stateFilePath), status.stdout)

        _ = try TestProcess.run(
            executable: loadout,
            arguments: ["unset", service, "--all"],
            extraEnvironment: testEnv
        )
    }

    func testImportDryRunDoesNotWrite() throws {
        let service = harness.uniqueService("dry")
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadout-cli-dry-\(UUID().uuidString).env")
        defer { try? FileManager.default.removeItem(at: source) }

        try """
        # \(service) prod
        export DRY_KEY="should-not-exist"
        """.write(to: source, atomically: true, encoding: .utf8)

        let dryRun = try TestProcess.run(
            executable: loadout,
            arguments: ["import", "--from", source.path, "--dry-run"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(dryRun.status, 0, dryRun.stderr)
        XCTAssertTrue(dryRun.stdout.contains("dry-run"), dryRun.stdout)

        let list = try TestProcess.run(
            executable: loadout,
            arguments: ["list"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(list.status, 0, list.stderr)
        XCTAssertFalse(list.stdout.contains(service), list.stdout)
    }

    func testUnsetDeletesSingleVariable() throws {
        let service = harness.uniqueService("one")
        XCTAssertEqual(
            try TestProcess.run(
                executable: loadout,
                arguments: ["set", service, "local", "KEEP", "1"],
                extraEnvironment: testEnv
            ).status,
            0
        )
        XCTAssertEqual(
            try TestProcess.run(
                executable: loadout,
                arguments: ["set", service, "local", "DROP", "2"],
                extraEnvironment: testEnv
            ).status,
            0
        )

        let unset = try TestProcess.run(
            executable: loadout,
            arguments: ["unset", service, "local", "DROP"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(unset.status, 0, unset.stderr)
        XCTAssertTrue(unset.stdout.contains("deleted"), unset.stdout)

        XCTAssertEqual(
            try TestProcess.run(
                executable: loadout,
                arguments: ["select", service, "local"],
                extraEnvironment: testEnv
            ).status,
            0
        )
        let export = try TestProcess.run(
            executable: loadout,
            arguments: ["export"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(export.status, 0, export.stderr)
        XCTAssertTrue(export.stdout.contains("KEEP"), export.stdout)
        XCTAssertFalse(export.stdout.contains("DROP"), export.stdout)

        _ = try TestProcess.run(
            executable: loadout,
            arguments: ["unset", service, "--all"],
            extraEnvironment: testEnv
        )
    }

    func testImportStoresValues() throws {
        let service = harness.uniqueService("cliimp")
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadout-cli-import-\(UUID().uuidString).env")
        defer { try? FileManager.default.removeItem(at: source) }

        try """
        # \(service) prod
        export ZZ_KEY="imported-value"
        """.write(to: source, atomically: true, encoding: .utf8)

        let importRun = try TestProcess.run(
            executable: loadout,
            arguments: ["import", "--from", source.path, "--yes"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(importRun.status, 0, importRun.stderr)
        XCTAssertTrue(importRun.stdout.contains("imported"), importRun.stdout)

        let select = try TestProcess.run(
            executable: loadout,
            arguments: ["select", service, "prod"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(select.status, 0, select.stderr)

        let export = try TestProcess.run(
            executable: loadout,
            arguments: ["export"],
            extraEnvironment: testEnv
        )
        XCTAssertEqual(export.status, 0, export.stderr)
        XCTAssertTrue(
            export.stdout.contains("export ZZ_KEY=") && export.stdout.contains("imported-value"),
            export.stdout
        )
    }
}