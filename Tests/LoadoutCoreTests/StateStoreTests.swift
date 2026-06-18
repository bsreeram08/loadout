import XCTest
@testable import LoadoutCore

final class StateStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadout-state-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        try super.tearDownWithError()
    }

    private func store() -> StateStore {
        StateStore(fileURL: tempDir.appendingPathComponent("state.json"))
    }

    func testSelectAndDeselect() throws {
        let store = store()
        _ = try store.select(service: "postgres", variant: "local")
        var state = try store.load()
        XCTAssertEqual(state.selection["postgres"], "local")
        XCTAssertTrue(state.order.contains("postgres"))

        _ = try store.deselect(service: "postgres")
        state = try store.load()
        XCTAssertNil(state.selection["postgres"])
    }

    func testSetOrderPreservesSelection() throws {
        let store = store()
        _ = try store.select(service: "b", variant: "prod")
        _ = try store.select(service: "a", variant: "dev")
        _ = try store.setOrder(["a", "b"])

        let state = try store.load()
        XCTAssertEqual(state.order, ["a", "b"])
        XCTAssertEqual(state.selection["a"], "dev")
        XCTAssertEqual(state.selection["b"], "prod")
    }

    func testLoadReturnsEmptyStateWhenMissing() throws {
        let state = try store().load()
        XCTAssertEqual(state.selection, [:])
        XCTAssertEqual(state.order, [])
    }
}