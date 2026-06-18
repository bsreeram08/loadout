import XCTest
@testable import LoadoutCore

/// Production keychain path via `security add-generic-password -w`.
/// These tests would have caught the empty-password write bug.
final class KeychainIntegrationTests: XCTestCase {
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

    func testSetRoundTripsValueThroughSecurityCLI() throws {
        let store = KeychainStore()
        let service = harness.uniqueService("svc")
        try store.set(service: service, variant: "local", variable: "API_KEY", value: "hello-world")
        XCTAssertEqual(try store.get(service: service, variant: "local", variable: "API_KEY"), "hello-world")
        _ = try store.deleteService(service)
    }

    func testSetOverwritesExistingValue() throws {
        let store = KeychainStore()
        let service = harness.uniqueService("svc")
        try store.set(service: service, variant: "dev", variable: "TOKEN", value: "first")
        try store.set(service: service, variant: "dev", variable: "TOKEN", value: "second")
        XCTAssertEqual(try store.get(service: service, variant: "dev", variable: "TOKEN"), "second")
        _ = try store.deleteService(service)
    }

    func testSetStoresEmptyString() throws {
        let store = KeychainStore()
        let service = harness.uniqueService("svc")
        try store.set(service: service, variant: "local", variable: "EMPTY", value: "")
        XCTAssertEqual(try store.get(service: service, variant: "local", variable: "EMPTY"), "")
        _ = try store.deleteService(service)
    }

    func testSetStoresSpecialCharacters() throws {
        let store = KeychainStore()
        let service = harness.uniqueService("svc")
        let value = "a=b\"c\\d'!@#$%"
        try store.set(service: service, variant: "prod", variable: "COMPLEX", value: value)
        XCTAssertEqual(try store.get(service: service, variant: "prod", variable: "COMPLEX"), value)
        _ = try store.deleteService(service)
    }

    func testExportEngineReadsStoredSecrets() throws {
        let store = KeychainStore()
        let stateStore = StateStore()
        let service = harness.uniqueService("svc")
        try store.set(service: service, variant: "local", variable: "DEMO_KEY", value: "demo-value")
        _ = try stateStore.select(service: service, variant: "local")

        let catalog = try KeychainCatalog()
        let result = try ExportEngine(stateStore: stateStore, keychain: store).export(catalog: catalog)
        XCTAssertTrue(result.lines.contains(ShellQuoting.exportLine(key: "DEMO_KEY", value: "demo-value")))

        _ = try store.deleteService(service)
        _ = try stateStore.removeServiceReferences(service)
    }

    func testImportStoresReadableValues() throws {
        let importer = ZshrcImporter()
        let store = KeychainStore()
        let service = harness.uniqueService("imp")
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadout-import-\(UUID().uuidString).env")
        defer { try? FileManager.default.removeItem(at: source) }

        try """
        # \(service) prod
        export IMPORT_ME="value-from-import"
        """.write(to: source, atomically: true, encoding: .utf8)

        let plan = try importer.plan(from: source.path)
        _ = try importer.execute(plan: plan, keychain: store, approvedProd: true)
        XCTAssertEqual(
            try store.get(service: service, variant: "prod", variable: "IMPORT_ME"),
            "value-from-import"
        )
        _ = try store.deleteService(service)
    }

    func testExportShadowsLowerPrecedenceCollision() throws {
        let store = KeychainStore()
        let stateStore = StateStore()
        let first = harness.uniqueService("a")
        let second = harness.uniqueService("b")

        try store.set(service: first, variant: "local", variable: "SHARED", value: "from-first")
        try store.set(service: second, variant: "local", variable: "SHARED", value: "from-second")
        _ = try stateStore.select(service: first, variant: "local")
        _ = try stateStore.select(service: second, variant: "local")
        _ = try stateStore.setOrder([first, second])

        let catalog = try KeychainCatalog()
        let result = try ExportEngine(stateStore: stateStore, keychain: store).export(catalog: catalog)

        XCTAssertEqual(result.lines, [ShellQuoting.exportLine(key: "SHARED", value: "from-first")])
        XCTAssertTrue(
            result.warnings.contains {
                $0.contains("SHARED") && $0.contains(first) && $0.contains("shadowed")
            },
            result.warnings.description
        )

        _ = try store.deleteService(first)
        _ = try store.deleteService(second)
        _ = try stateStore.removeServiceReferences(first)
        _ = try stateStore.removeServiceReferences(second)
    }

    func testDeleteServiceRemovesCatalogEntry() throws {
        let store = KeychainStore()
        let service = harness.uniqueService("del")
        try store.set(service: service, variant: "dev", variable: "TEMP", value: "x")
        XCTAssertFalse(try KeychainCatalog().registry().filter { $0.service == service }.isEmpty)

        _ = try store.deleteService(service)
        XCTAssertTrue(try KeychainCatalog().registry().filter { $0.service == service }.isEmpty)
    }

    func testCatalogMatchesStoredRegistry() throws {
        let store = KeychainStore()
        let service = harness.uniqueService("cat")
        try store.set(service: service, variant: "dev", variable: "A", value: "1")
        try store.set(service: service, variant: "dev", variable: "B", value: "2")
        try store.set(service: service, variant: "prod", variable: "C", value: "3")

        let catalog = try KeychainCatalog()
        let entry = catalog.registry().first { $0.service == service }
        XCTAssertNotNil(entry)
        XCTAssertEqual(Set(entry?.variants ?? []), Set(["dev", "prod"]))
        XCTAssertEqual(entry?.variableCounts["dev"], 2)
        XCTAssertEqual(entry?.variableCounts["prod"], 1)
        XCTAssertEqual(catalog.variableNames(service: service, variant: "dev").sorted(), ["A", "B"])

        _ = try store.deleteService(service)
    }
}