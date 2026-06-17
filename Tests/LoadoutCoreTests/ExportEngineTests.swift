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
}