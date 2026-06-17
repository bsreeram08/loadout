import Foundation

public struct ParsedAssignment: Equatable, Sendable {
    public let variable: String
    public let value: String
    public let lineNumber: Int

    public init(variable: String, value: String, lineNumber: Int) {
        self.variable = variable
        self.value = value
        self.lineNumber = lineNumber
    }
}

public enum ExportLineParser {
    private static let exportPattern = #"^\s*export\s+(?:const\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$"#

    public static func parseActiveExport(line: String, lineNumber: Int) -> ParsedAssignment? {
        guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("#") else { return nil }
        return parseExport(line: line, lineNumber: lineNumber)
    }

    public static func parseCommentedExport(line: String, lineNumber: Int) -> ParsedAssignment? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        let uncommented = trimmed.drop(while: { $0 == "#" || $0.isWhitespace })
        return parseExport(line: String(uncommented), lineNumber: lineNumber)
    }

    public static func parseExport(line: String, lineNumber: Int) -> ParsedAssignment? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.range(of: exportPattern, options: .regularExpression) else {
            return nil
        }
        let matched = String(trimmed[match])
        guard let equalsIndex = matched.firstIndex(of: "=") else { return nil }

        let head = matched[..<equalsIndex]
        let variable = head
            .replacingOccurrences(of: "export", with: "")
            .replacingOccurrences(of: "const", with: "")
            .trimmingCharacters(in: .whitespaces)

        let rawValue = String(matched[matched.index(after: equalsIndex)...])
            .trimmingCharacters(in: .whitespaces)

        guard let value = parseValue(rawValue) else { return nil }
        return ParsedAssignment(variable: variable, value: value, lineNumber: lineNumber)
    }

    public static func parseValue(_ raw: String) -> String? {
        guard !raw.isEmpty else { return "" }

        if raw.hasPrefix("$'") {
            return parseZshCString(String(raw.dropFirst(2)))
        }
        if raw.hasPrefix("'") {
            return parseSingleQuoted(String(raw.dropFirst()))
        }
        if raw.hasPrefix("\"") {
            return parseDoubleQuoted(String(raw.dropFirst()))
        }

        let unquoted = stripInlineComment(raw).trimmingCharacters(in: .whitespaces)
        return unquoted.isEmpty ? nil : unquoted
    }

    private static func parseZshCString(_ input: String) -> String? {
        guard input.hasSuffix("'") else { return nil }
        var value = ""
        var index = input.startIndex
        let end = input.index(before: input.endIndex)

        while index < end {
            let char = input[index]
            if char == "\\" {
                index = input.index(after: index)
                guard index < end else { return nil }
                let escaped = input[index]
                switch escaped {
                case "n": value.append("\n")
                case "t": value.append("\t")
                case "r": value.append("\r")
                case "\\": value.append("\\")
                case "'": value.append("'")
                case "\"": value.append("\"")
                case "a": value.append("\u{07}")
                case "b": value.append("\u{08}")
                case "f": value.append("\u{0C}")
                case "v": value.append("\u{0B}")
                default:
                    value.append(escaped)
                }
            } else {
                value.append(char)
            }
            index = input.index(after: index)
        }
        return value
    }

    private static func parseSingleQuoted(_ input: String) -> String? {
        guard input.hasSuffix("'") else { return nil }
        return String(input.dropLast())
    }

    private static func parseDoubleQuoted(_ input: String) -> String? {
        guard input.hasSuffix("\"") else { return nil }
        var value = ""
        var index = input.startIndex
        let end = input.index(before: input.endIndex)

        while index < end {
            let char = input[index]
            if char == "\\" {
                index = input.index(after: index)
                guard index < end else { return nil }
                value.append(input[index])
            } else {
                value.append(char)
            }
            index = input.index(after: index)
        }
        return value
    }

    private static func stripInlineComment(_ raw: String) -> String {
        var inSingle = false
        var inDouble = false
        var index = raw.startIndex

        while index < raw.endIndex {
            let char = raw[index]
            if char == "'" && !inDouble { inSingle.toggle() }
            if char == "\"" && !inSingle { inDouble.toggle() }
            if char == "#" && !inSingle && !inDouble {
                return String(raw[..<index])
            }
            index = raw.index(after: index)
        }
        return raw
    }
}