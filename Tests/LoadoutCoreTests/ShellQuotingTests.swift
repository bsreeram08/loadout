import XCTest
@testable import LoadoutCore

final class ShellQuotingTests: XCTestCase {
    func testSimpleValue() {
        XCTAssertEqual(
            ShellQuoting.exportLine(key: "PORT", value: "8080"),
            "export PORT=$'8080'"
        )
    }

    func testQuotesAndBackslash() {
        XCTAssertEqual(
            ShellQuoting.zshCStringLiteral(#"it's a "test"\"#),
            #"$'it\'s a \"test\"\\'"#
        )
    }

    func testNewline() {
        XCTAssertEqual(
            ShellQuoting.zshCStringLiteral("a\nb"),
            #"$'a\nb'"#
        )
    }
}