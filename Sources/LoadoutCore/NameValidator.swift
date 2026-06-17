import Foundation

public enum NameValidator {
    private static let pattern = #"^[a-z][a-z0-9_-]*$"#

    public static func validateService(_ name: String) throws {
        guard name.range(of: pattern, options: .regularExpression) != nil else {
            throw LoadoutError.invalidServiceName(name)
        }
    }

    public static func validateVariant(_ name: String) throws {
        guard name.range(of: pattern, options: .regularExpression) != nil else {
            throw LoadoutError.invalidVariantName(name)
        }
    }

    public static func validateVariable(_ name: String) throws {
        guard !name.isEmpty,
              name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
              name.first?.isLetter == true || name.first == "_"
        else {
            throw LoadoutError.invalidVariableName(name)
        }
    }
}