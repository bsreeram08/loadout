import Darwin
import Foundation

enum KeychainAccess {
    static func unlockLoginKeychain() throws {
        let keychain = loginKeychainPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["unlock-keychain", "-u", keychain]
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw LoadoutError.io("failed to unlock login keychain (exit \(process.terminationStatus))")
        }
    }

    static func currentCDHash() throws -> String {
        let path = executablePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dv", "--verbose=4", path]

        let output = Pipe()
        process.standardError = output
        process.standardOutput = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if let cdhash = parseCDHash(from: text) {
            return cdhash
        }

        throw LoadoutError.io(
            "could not read CDHash for \(path) — run ./scripts/install.sh to ad-hoc sign loadout"
        )
    }

    static func parseCDHash(from codesignOutput: String) -> String? {
        for line in codesignOutput.components(separatedBy: .newlines) {
            if line.hasPrefix("CDHash=") {
                return String(line.dropFirst("CDHash=".count))
            }
            if line.hasPrefix("CandidateCDHash sha256=") {
                return String(line.dropFirst("CandidateCDHash sha256=".count))
            }
        }
        return nil
    }

    static var loginKeychainPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Keychains/login.keychain-db")
            .path
    }

    static var executablePath: String {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        var size = UInt32(buffer.count)
        if _NSGetExecutablePath(&buffer, &size) == 0 {
            let raw = String(cString: buffer)
            return (raw as NSString).resolvingSymlinksInPath
        }
        let fallback = CommandLine.arguments[0]
        return (fallback as NSString).standardizingPath
    }
}