import Foundation

public enum ShellQuoting {
    /// Emits `export KEY=$'...'` safe for zsh eval.
    public static func exportLine(key: String, value: String) -> String {
        "export \(key)=\(zshCStringLiteral(value))"
    }

    public static func zshCStringLiteral(_ value: String) -> String {
        var escaped = "$'"
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x07: escaped += "\\a"
            case 0x08: escaped += "\\b"
            case 0x0C: escaped += "\\f"
            case 0x0A: escaped += "\\n"
            case 0x0D: escaped += "\\r"
            case 0x09: escaped += "\\t"
            case 0x0B: escaped += "\\v"
            case 0x5C: escaped += "\\\\"
            case 0x27: escaped += "\\'"
            case 0x22: escaped += "\\\""
            case 0x3F: escaped += "\\?"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7F {
                    escaped += String(format: "\\%03o", scalar.value)
                } else {
                    escaped += String(Character(scalar))
                }
            }
        }
        escaped += "'"
        return escaped
    }
}