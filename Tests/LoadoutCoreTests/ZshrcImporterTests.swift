import XCTest
@testable import LoadoutCore

final class ZshrcImporterTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try KeychainSearchListGuard.ensureLoginKeychainOnly()
        setenv("LOADOUT_SKIP_PARTITION", "1", 1)
    }

    override func tearDownWithError() throws {
        let store = KeychainStore()
        for service in ["worldline", "bambora", "swish"] {
            _ = try? store.deleteService(service)
        }
        unsetenv("LOADOUT_SKIP_PARTITION")
        try super.tearDownWithError()
    }

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/sample.zshrc")
    }

    func testPlanDetectsBlocksSelectionAndServices() throws {
        let plan = try ZshrcImporter().plan(from: fixtureURL.path)

        XCTAssertEqual(plan.serviceCount, 3)
        XCTAssertEqual(plan.proposedSelection["worldline"], "prod")
        XCTAssertEqual(plan.proposedSelection["bambora"], "test")
        XCTAssertEqual(plan.proposedSelection["swish"], "prod")
        XCTAssertTrue(plan.prodServices.contains("worldline"))
        XCTAssertTrue(plan.prodServices.contains("swish"))
        XCTAssertFalse(plan.prodServices.contains("bambora"))
    }

    func testPlanIncludesInactiveAssignments() throws {
        let plan = try ZshrcImporter().plan(from: fixtureURL.path)
        let worldlineProd = plan.blocks.first { $0.service == "worldline" && $0.variant == "prod" }
        XCTAssertEqual(worldlineProd?.active.count, 2)
        XCTAssertEqual(worldlineProd?.inactive.count, 1)
    }

    func testExecuteStoresInactiveUnderAlternateVariant() throws {
        let plan = try ZshrcImporter().plan(from: fixtureURL.path)
        let keychain = KeychainStore()
        _ = try ZshrcImporter().execute(plan: plan, keychain: keychain, approvedProd: true)

        XCTAssertEqual(try keychain.get(service: "worldline", variant: "prod", variable: "WORLDPAY_API_KEY"), "prod-secret-key")
        XCTAssertEqual(try keychain.get(service: "worldline", variant: "dev", variable: "WORLDPAY_API_KEY"), "dev-secret-key")
        XCTAssertEqual(try keychain.get(service: "bambora", variant: "test", variable: "BAMBORA_TOKEN"), "test-token")
        XCTAssertEqual(try keychain.get(service: "bambora", variant: "prod", variable: "BAMBORA_TOKEN"), "prod-token")
    }

    func testServiceGrouperMapsPrefixes() {
        XCTAssertEqual(ServiceGrouper.serviceName(from: "WORLDPAY_API_KEY"), "worldline")
        XCTAssertEqual(ServiceGrouper.serviceName(from: "BAMBORA_TOKEN"), "bambora")
        XCTAssertEqual(ServiceGrouper.serviceName(from: "SWISH_MERCHANT_ID"), "swish")
    }

    func testCommentInference() {
        let hint = ServiceGrouper.inferFromComment("# Bambora test")
        XCTAssertEqual(hint.service, "bambora")
        XCTAssertEqual(hint.variant, "test")
    }
}