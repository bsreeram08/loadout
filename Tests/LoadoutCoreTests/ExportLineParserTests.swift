import XCTest
@testable import LoadoutCore

final class ExportLineParserTests: XCTestCase {
    func testParsesSimpleExport() {
        let parsed = ExportLineParser.parseExport(
            line: "export PORT=8080",
            lineNumber: 1
        )
        XCTAssertEqual(parsed, ParsedAssignment(variable: "PORT", value: "8080", lineNumber: 1))
    }

    func testParsesExportConstTypo() {
        let parsed = ExportLineParser.parseExport(
            line: "export const API_KEY=abc",
            lineNumber: 2
        )
        XCTAssertEqual(parsed, ParsedAssignment(variable: "API_KEY", value: "abc", lineNumber: 2))
    }

    func testParsesDoubleQuotedValue() {
        let parsed = ExportLineParser.parseExport(
            line: #"export TOKEN="hello \"world\"""#,
            lineNumber: 3
        )
        XCTAssertEqual(parsed?.value, #"hello "world""#)
    }

    func testParsesCommentedExport() {
        let parsed = ExportLineParser.parseCommentedExport(
            line: "# export FOO=bar",
            lineNumber: 4
        )
        XCTAssertEqual(parsed, ParsedAssignment(variable: "FOO", value: "bar", lineNumber: 4))
    }

    func testParsesEmptyQuotedValue() {
        XCTAssertEqual(ExportLineParser.parseValue("\"\""), "")
        XCTAssertEqual(ExportLineParser.parseValue("''"), "")
    }

    func testParsesUnquotedValueWithInlineComment() {
        XCTAssertEqual(ExportLineParser.parseValue("8080 # default port"), "8080")
    }

    func testSkipsNonExportLines() {
        XCTAssertNil(ExportLineParser.parseActiveExport(line: "echo hello", lineNumber: 1))
        XCTAssertNil(ExportLineParser.parseActiveExport(line: "FOO=bar", lineNumber: 1))
    }

    func testParsesZshCString() {
        let parsed = ExportLineParser.parseExport(
            line: #"export MSG=$'line1\nline2'"#,
            lineNumber: 5
        )
        XCTAssertEqual(parsed?.value, "line1\nline2")
    }
}