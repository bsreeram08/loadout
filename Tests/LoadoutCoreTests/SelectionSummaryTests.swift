import XCTest
@testable import LoadoutCore

final class SelectionSummaryTests: XCTestCase {
    private let registry = [
        RegistryEntry(
            service: "worldline",
            variants: ["dev", "prod"],
            variableCounts: ["dev": 1, "prod": 2]
        ),
        RegistryEntry(
            service: "bambora",
            variants: ["test"],
            variableCounts: ["test": 1]
        ),
    ]

    func testComputeCountsAndProdFlag() {
        let state = LoadoutState(selection: ["worldline": "prod", "bambora": "test"])
        let summary = SelectionSummary.compute(state: state, registry: registry)

        XCTAssertEqual(summary.selectedServiceCount, 2)
        XCTAssertEqual(summary.selectedVariableCount, 3)
        XCTAssertTrue(summary.hasProdSelected)
        XCTAssertEqual(summary.footerLabel, "2 services selected · 3 vars")
    }

    func testFooterLabelUsesSingularNouns() {
        let summary = SelectionSummary(
            selectedServiceCount: 1,
            selectedVariableCount: 1,
            hasProdSelected: false
        )
        XCTAssertEqual(summary.footerLabel, "1 service selected · 1 var")
    }

    func testFooterLabelUsesPluralNouns() {
        let summary = SelectionSummary(
            selectedServiceCount: 2,
            selectedVariableCount: 5,
            hasProdSelected: true
        )
        XCTAssertEqual(summary.footerLabel, "2 services selected · 5 vars")
    }

    func testMissingVariantCountsAsZero() {
        let state = LoadoutState(selection: ["worldline": "staging"])
        let summary = SelectionSummary.compute(state: state, registry: registry)

        XCTAssertEqual(summary.selectedVariableCount, 0)
        XCTAssertFalse(summary.hasProdSelected)
    }
}