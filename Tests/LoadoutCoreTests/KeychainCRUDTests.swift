import XCTest
@testable import LoadoutCore

final class KeychainCRUDTests: XCTestCase {
    override func setUp() {
        super.setUp()
        setenv("LOADOUT_SKIP_PARTITION", "1", 1)
    }

    func testDeleteVariableRemovesFromRegistry() throws {
        let store = KeychainStore()
        let service = "testsvc\(UUID().uuidString.prefix(6).lowercased())"
        try store.set(service: service, variant: "dev", variable: "API_KEY", value: "secret")
        XCTAssertEqual(try store.variableNames(service: service, variant: "dev"), ["API_KEY"])

        try store.deleteVariable(service: service, variant: "dev", variable: "API_KEY")
        XCTAssertTrue(try store.variableNames(service: service, variant: "dev").isEmpty)
        XCTAssertTrue(try store.registry().filter { $0.service == service }.isEmpty)

        _ = try store.deleteService(service)
    }

    func testDeleteVariantClearsSelectionWhenActive() throws {
        let store = KeychainStore()
        let stateStore = StateStore()
        let service = "testsvc\(UUID().uuidString.prefix(6).lowercased())"

        try store.set(service: service, variant: "dev", variable: "A", value: "1")
        try store.set(service: service, variant: "prod", variable: "B", value: "2")
        _ = try stateStore.select(service: service, variant: "prod")

        let deleted = try store.deleteVariant(service: service, variant: "prod")
        XCTAssertEqual(deleted, 1)

        var state = try stateStore.load()
        if state.selection[service] == "prod" {
            _ = try stateStore.deselect(service: service)
            state = try stateStore.load()
        }
        XCTAssertNil(state.selection[service])

        _ = try store.deleteService(service)
        _ = try stateStore.removeServiceReferences(service)
    }

    func testRemoveServiceReferences() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadout-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stateStore = StateStore(fileURL: tempDir.appendingPathComponent("state.json"))
        _ = try stateStore.select(service: "alpha", variant: "dev")
        _ = try stateStore.select(service: "beta", variant: "prod")
        _ = try stateStore.setOrder(["beta", "alpha"])

        let next = try stateStore.removeServiceReferences("beta")
        XCTAssertNil(next.selection["beta"])
        XCTAssertFalse(next.order.contains("beta"))
        XCTAssertEqual(next.selection["alpha"], "dev")
    }
}