import Foundation

public enum ConsolePrompt {
    public static func confirm(
        _ message: String,
        defaultYes: Bool = false,
        io: SelectWizard.IO = .standard
    ) -> Bool {
        let suffix = defaultYes ? "[Y/n]" : "[y/N]"
        io.writePrompt("\(message) \(suffix) ")
        guard let line = readInputLine(from: io)?.lowercased() else { return false }
        if line.isEmpty { return defaultYes }
        return line == "y" || line == "yes"
    }

    public static func requireYes(_ message: String) -> Bool {
        print(message)
        print("Type 'yes' to continue: ", terminator: "")
        fflush(stdout)
        return readInputLine(from: .standard)?.lowercased() == "yes"
    }

    private static func readInputLine(from io: SelectWizard.IO) -> String? {
        io.readLine()?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}