import XCTest
@testable import LoadoutCore

final class SelectWizardTests: XCTestCase {
    private let registry = [
        RegistryEntry(
            service: "bambora",
            variants: ["prod", "test"],
            variableCounts: ["prod": 1, "test": 2]
        ),
        RegistryEntry(
            service: "swish",
            variants: ["prod"],
            variableCounts: ["prod": 1]
        ),
    ]

    func testPromptSelectsServiceAndVariant() throws {
        let wizard = SelectWizard()
        let session = ScriptedIO(inputs: ["1", "2"])
        let action = try wizard.prompt(
            registry: registry,
            state: LoadoutState(),
            io: session.io
        )
        XCTAssertEqual(action, .select(service: "bambora", variant: "test"))
    }

    func testPromptDeselectsService() throws {
        let wizard = SelectWizard()
        let state = LoadoutState(selection: ["bambora": "prod"])
        let session = ScriptedIO(inputs: ["1", "d"])
        let action = try wizard.prompt(
            registry: registry,
            state: state,
            io: session.io
        )
        XCTAssertEqual(action, .deselect(service: "bambora"))
    }

    func testPromptQuitFromServiceList() throws {
        let wizard = SelectWizard()
        let session = ScriptedIO(inputs: ["q"])
        let action = try wizard.prompt(
            registry: registry,
            state: LoadoutState(),
            io: session.io
        )
        XCTAssertEqual(action, .quit)
    }

    func testPromptBackReturnsToServiceList() throws {
        let wizard = SelectWizard()
        let session = ScriptedIO(inputs: ["2", "b", "q"])
        let action = try wizard.prompt(
            registry: registry,
            state: LoadoutState(),
            io: session.io
        )
        XCTAssertEqual(action, .quit)
        XCTAssertTrue(session.output.contains { $0.contains("Services:") })
        XCTAssertTrue(session.output.contains { $0.contains("Variants for swish:") })
    }
}

private final class ScriptedIO {
    private var remaining: [String]
    private(set) var output: [String] = []

    var io: SelectWizard.IO {
        SelectWizard.IO(
            write: { [weak self] line in self?.output.append(line) },
            writePrompt: { [weak self] prompt in self?.output.append(prompt) },
            readLine: { [weak self] in
                guard let self, !self.remaining.isEmpty else { return nil }
                return self.remaining.removeFirst()
            }
        )
    }

    init(inputs: [String]) {
        remaining = inputs
    }
}