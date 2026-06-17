import Foundation

public struct SelectionSummary: Equatable, Sendable {
    public let selectedServiceCount: Int
    public let selectedVariableCount: Int
    public let hasProdSelected: Bool

    public init(
        selectedServiceCount: Int,
        selectedVariableCount: Int,
        hasProdSelected: Bool
    ) {
        self.selectedServiceCount = selectedServiceCount
        self.selectedVariableCount = selectedVariableCount
        self.hasProdSelected = hasProdSelected
    }

    public var footerLabel: String {
        let serviceNoun = selectedServiceCount == 1 ? "service" : "services"
        let varNoun = selectedVariableCount == 1 ? "var" : "vars"
        return "\(selectedServiceCount) \(serviceNoun) selected · \(selectedVariableCount) \(varNoun)"
    }

    public static func compute(state: LoadoutState, registry: [RegistryEntry]) -> SelectionSummary {
        let registryByService = Dictionary(uniqueKeysWithValues: registry.map { ($0.service, $0) })
        var variableCount = 0
        var hasProd = false

        for (service, variant) in state.selection {
            if variant == "prod" {
                hasProd = true
            }
            if let entry = registryByService[service],
               let count = entry.variableCounts[variant]
            {
                variableCount += count
            }
        }

        return SelectionSummary(
            selectedServiceCount: state.selection.count,
            selectedVariableCount: variableCount,
            hasProdSelected: hasProd
        )
    }
}