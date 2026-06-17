import Foundation

public enum ServiceGrouper {
    private static let prefixMap: [String: String] = [
        "WORLDPAY": "worldline",
        "WORLDLINE": "worldline",
        "BAMBORA": "bambora",
        "SWISH": "swish",
        "KLARNA": "klarna",
        "NETS": "nets",
        "FISERV": "fiserv",
        "SLACK": "slack",
        "POSTGRES": "postgres",
        "PG": "postgres",
        "AWS": "aws",
        "HSM": "hsm",
    ]

    private static let variantTokens: Set<String> = [
        "dev", "development", "beta", "test", "testing", "staging", "prod", "production", "local",
    ]

    public static func serviceName(from variable: String) -> String {
        let parts = variable.split(separator: "_", omittingEmptySubsequences: false)
        if parts.count >= 2 {
            let prefix = String(parts[0]).uppercased()
            if let mapped = prefixMap[prefix] {
                return mapped
            }
            return slug(String(parts[0]))
        }
        return "misc"
    }

    public static func inferFromComment(_ line: String) -> (service: String?, variant: String?) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return (nil, nil) }
        let body = trimmed
            .drop(while: { $0 == "#" || $0.isWhitespace })
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !body.isEmpty else { return (nil, nil) }

        let tokens = body
            .replacingOccurrences(of: "---", with: " ")
            .replacingOccurrences(of: "===", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        var service: String?
        var variant: String?

        for token in tokens {
            let normalized = normalizeVariant(token)
            if variantTokens.contains(normalized) {
                variant = normalized
                continue
            }
            if service == nil, !variantTokens.contains(token), token.count > 2 {
                service = slug(token)
            }
        }

        return (service, variant)
    }

    public static func normalizeVariant(_ token: String) -> String {
        switch token.lowercased() {
        case "development": return "dev"
        case "production": return "prod"
        case "testing": return "test"
        case "staging": return "staging"
        case "local": return "local"
        default: return token.lowercased()
        }
    }

    public static func slug(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let cleaned = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "-" {
                return Character(scalar)
            }
            return "-"
        }
        let collapsed = String(cleaned)
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if collapsed.isEmpty { return "misc" }
        if collapsed.first?.isNumber == true { return "svc-\(collapsed)" }
        return collapsed
    }
}