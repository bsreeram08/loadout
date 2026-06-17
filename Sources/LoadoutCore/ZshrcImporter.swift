import Foundation

public struct ImportBlock: Equatable, Sendable {
    public let service: String
    public let variant: String
    public let active: [ParsedAssignment]
    public let inactive: [ParsedAssignment]

    public init(service: String, variant: String, active: [ParsedAssignment], inactive: [ParsedAssignment]) {
        self.service = service
        self.variant = variant
        self.active = active
        self.inactive = inactive
    }

    public var allAssignments: [ParsedAssignment] {
        active + inactive
    }
}

public struct ImportPlan: Equatable, Sendable {
    public let sourcePath: String
    public let blocks: [ImportBlock]
    public let proposedSelection: [String: String]
    public let warnings: [String]
    public let variableCount: Int
    public let serviceCount: Int

    public init(
        sourcePath: String,
        blocks: [ImportBlock],
        proposedSelection: [String: String],
        warnings: [String],
        variableCount: Int,
        serviceCount: Int
    ) {
        self.sourcePath = sourcePath
        self.blocks = blocks
        self.proposedSelection = proposedSelection
        self.warnings = warnings
        self.variableCount = variableCount
        self.serviceCount = serviceCount
    }

    public var prodServices: [String] {
        proposedSelection
            .filter { $0.value == "prod" }
            .map(\.key)
            .sorted()
    }
}

public struct ImportResult: Sendable {
    public let importedVariables: Int
    public let selection: [String: String]

    public init(importedVariables: Int, selection: [String: String]) {
        self.importedVariables = importedVariables
        self.selection = selection
    }
}

public struct ZshrcImporter: Sendable {
    public init() {}

    public func plan(from path: String) throws -> ImportPlan {
        let expanded = NSString(string: path).expandingTildeInPath
        let contents = try String(contentsOfFile: expanded, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines)

        var blocks: [ImportBlock] = []
        var warnings: [String] = []

        var currentService: String?
        var currentVariant: String?
        var activeBucket: [ParsedAssignment] = []
        var inactiveBucket: [ParsedAssignment] = []

        func flushBlock() {
            guard let service = currentService, let variant = currentVariant else { return }
            guard !activeBucket.isEmpty || !inactiveBucket.isEmpty else { return }
            blocks.append(
                ImportBlock(
                    service: service,
                    variant: variant,
                    active: activeBucket,
                    inactive: inactiveBucket
                )
            )
            activeBucket = []
            inactiveBucket = []
        }

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("#") {
                if let active = ExportLineParser.parseCommentedExport(line: line, lineNumber: lineNumber) {
                    if currentService == nil {
                        currentService = ServiceGrouper.serviceName(from: active.variable)
                    }
                    if currentVariant == nil {
                        currentVariant = "default"
                    }
                    inactiveBucket.append(active)
                    continue
                }

                let hint = ServiceGrouper.inferFromComment(line)
                if hint.service != nil || hint.variant != nil {
                    flushBlock()
                    if let service = hint.service { currentService = service }
                    if let variant = hint.variant { currentVariant = variant }
                    if currentService != nil && currentVariant == nil {
                        currentVariant = "default"
                    }
                }
                continue
            }

            guard let active = ExportLineParser.parseActiveExport(line: line, lineNumber: lineNumber)
                ?? parseDotenv(line: line, lineNumber: lineNumber)
            else {
                continue
            }

            if currentService == nil {
                currentService = ServiceGrouper.serviceName(from: active.variable)
            }
            if currentVariant == nil {
                currentVariant = "default"
            }

            activeBucket.append(active)
        }

        flushBlock()

        if blocks.isEmpty {
            throw LoadoutError.io("no export statements found in \(expanded)")
        }

        blocks = mergeBlocks(blocks)

        var selection: [String: String] = [:]
        for block in blocks where !block.active.isEmpty {
            if let existing = selection[block.service], existing != block.variant {
                warnings.append(
                    "multiple active variants for \(block.service): keeping \(block.variant) over \(existing)"
                )
            }
            selection[block.service] = block.variant
        }

        let variableCount = blocks.reduce(0) { $0 + $1.allAssignments.count }
        let serviceCount = Set(blocks.map(\.service)).count

        return ImportPlan(
            sourcePath: expanded,
            blocks: blocks,
            proposedSelection: selection,
            warnings: warnings,
            variableCount: variableCount,
            serviceCount: serviceCount
        )
    }

    public func execute(
        plan: ImportPlan,
        keychain: KeychainStore = KeychainStore(),
        stateStore: StateStore = StateStore(),
        approvedProd: Bool
    ) throws -> ImportResult {
        if !plan.prodServices.isEmpty && !approvedProd {
            throw LoadoutError.io("prod import not approved")
        }

        var imported = 0
        for block in plan.blocks {
            for assignment in block.active {
                try keychain.set(
                    service: block.service,
                    variant: block.variant,
                    variable: assignment.variable,
                    value: assignment.value
                )
                imported += 1
            }

            if block.active.isEmpty {
                for assignment in block.inactive {
                    try keychain.set(
                        service: block.service,
                        variant: block.variant,
                        variable: assignment.variable,
                        value: assignment.value
                    )
                    imported += 1
                }
            } else {
                let altVariant = alternateVariant(for: block.variant)
                for assignment in block.inactive {
                    try keychain.set(
                        service: block.service,
                        variant: altVariant,
                        variable: assignment.variable,
                        value: assignment.value
                    )
                    imported += 1
                }
            }
        }

        var state = try stateStore.load()
        state.selection = plan.proposedSelection
        state.order = plan.proposedSelection.keys.sorted()
        _ = try stateStore.save(state)

        return ImportResult(importedVariables: imported, selection: plan.proposedSelection)
    }

    private func parseDotenv(line: String, lineNumber: Int) -> ParsedAssignment? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("#"),
              !trimmed.hasPrefix("export")
        else { return nil }
        guard let equals = trimmed.firstIndex(of: "=") else { return nil }
        let variable = String(trimmed[..<equals])
        guard variable.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil else {
            return nil
        }
        let rawValue = String(trimmed[trimmed.index(after: equals)...])
            .trimmingCharacters(in: .whitespaces)
        guard let value = ExportLineParser.parseValue(rawValue) else { return nil }
        return ParsedAssignment(variable: variable, value: value, lineNumber: lineNumber)
    }

    private func alternateVariant(for variant: String) -> String {
        switch variant {
        case "prod": return "dev"
        case "dev": return "prod"
        case "test": return "prod"
        case "beta": return "prod"
        default: return "\(variant)-alt"
        }
    }

    private func mergeBlocks(_ blocks: [ImportBlock]) -> [ImportBlock] {
        var merged: [String: ImportBlock] = [:]
        for block in blocks {
            let key = "\(block.service):\(block.variant)"
            if let existing = merged[key] {
                merged[key] = ImportBlock(
                    service: block.service,
                    variant: block.variant,
                    active: existing.active + block.active,
                    inactive: existing.inactive + block.inactive
                )
            } else {
                merged[key] = block
            }
        }
        return merged.values.sorted {
            $0.service == $1.service ? $0.variant < $1.variant : $0.service < $1.service
        }
    }
}