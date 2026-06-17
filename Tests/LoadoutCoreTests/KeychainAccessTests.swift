import XCTest
@testable import LoadoutCore

final class KeychainAccessTests: XCTestCase {
    func testParseCDHashFromCodesignOutput() {
        let output = """
        CandidateCDHash sha256=fb2f64fdce2b697466f8004cfe61736e7cf2cdd9
        CDHash=fb2f64fdce2b697466f8004cfe61736e7cf2cdd9
        """
        XCTAssertEqual(
            KeychainAccess.parseCDHash(from: output),
            "fb2f64fdce2b697466f8004cfe61736e7cf2cdd9"
        )
    }

    func testExecutablePathIsAbsolute() {
        XCTAssertTrue(KeychainAccess.executablePath.hasPrefix("/"))
    }

    func testAccessPolicyMentionsDedicatedKeychain() throws {
        setenv("LOADOUT_SKIP_PARTITION", "1", 1)
        let store = KeychainStore()
        let description = try store.accessPolicyDescription()
        XCTAssertTrue(description.contains("loadout.keychain-db"))
        XCTAssertTrue(description.contains("allow-any-app"))
    }
}