import XCTest
@testable import LoadoutCore

final class NameValidatorTests: XCTestCase {
    func testAcceptsValidServiceNames() throws {
        for name in ["worldline", "b2", "my-service", "a_b"] {
            XCTAssertNoThrow(try NameValidator.validateService(name), name)
        }
    }

    func testRejectsInvalidServiceNames() {
        for name in ["", "Worldline", "1bad", "has space", "UPPER"] {
            XCTAssertThrowsError(try NameValidator.validateService(name)) { error in
                guard case LoadoutError.invalidServiceName(let rejected) = error else {
                    return XCTFail("expected invalidServiceName, got \(error)")
                }
                XCTAssertEqual(rejected, name)
            }
        }
    }

    func testAcceptsValidVariantNames() throws {
        for name in ["prod", "dev", "test", "local-2"] {
            XCTAssertNoThrow(try NameValidator.validateVariant(name), name)
        }
    }

    func testRejectsInvalidVariantNames() {
        for name in ["", "PROD", "9prod"] {
            XCTAssertThrowsError(try NameValidator.validateVariant(name)) { error in
                if case LoadoutError.invalidVariantName = error {
                    return
                }
                XCTFail("expected invalidVariantName, got \(error)")
            }
        }
    }

    func testAcceptsValidVariableNames() throws {
        for name in ["API_KEY", "_SECRET", "PORT", "A1"] {
            XCTAssertNoThrow(try NameValidator.validateVariable(name), name)
        }
    }

    func testRejectsInvalidVariableNames() {
        for name in ["", "9KEY", "HAS-DASH", "has.dot"] {
            XCTAssertThrowsError(try NameValidator.validateVariable(name)) { error in
                if case LoadoutError.invalidVariableName = error {
                    return
                }
                XCTFail("expected invalidVariableName, got \(error)")
            }
        }
    }
}