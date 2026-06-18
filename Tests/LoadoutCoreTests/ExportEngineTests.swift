import XCTest
@testable import LoadoutCore

final class ExportEngineTests: XCTestCase {
    func testOrderedSelectionServicesUsesOrderFirst() {
        let state = LoadoutState(
            selection: ["bambora": "test", "worldline": "prod", "swish": "prod"],
            order: ["swish", "worldline", "bambora"]
        )
        let engine = ExportEngine()
        XCTAssertEqual(
            engine.orderedSelectionServices(state: state),
            ["swish", "worldline", "bambora"]
        )
    }

    func testOrderedSelectionServicesFallsBackToAlphabetical() {
        let state = LoadoutState(
            selection: ["bambora": "test", "worldline": "prod"],
            order: []
        )
        let engine = ExportEngine()
        XCTAssertEqual(
            engine.orderedSelectionServices(state: state),
            ["bambora", "worldline"]
        )
    }

    func testExportReturnsEmptyWhenNothingSelected() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadout-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stateStore = StateStore(fileURL: tempDir.appendingPathComponent("state.json"))
        let result = try ExportEngine(stateStore: stateStore).export()
        XCTAssertTrue(result.lines.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
    }
}