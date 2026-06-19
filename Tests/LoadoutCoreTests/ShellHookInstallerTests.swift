import XCTest
@testable import LoadoutCore

final class ShellHookInstallerTests: XCTestCase {
    private var tempDir: URL!
    private var zshrc: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadout-shell-hook-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        zshrc = tempDir.appendingPathComponent(".zshrc")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        zshrc = nil
        try super.tearDownWithError()
    }

    func testInstallCreatesMarkedHookBlock() throws {
        let installer = ShellHookInstaller()
        XCTAssertTrue(try installer.installOrUpdate(fileURL: zshrc))

        let contents = try String(contentsOf: zshrc, encoding: .utf8)
        XCTAssertTrue(contents.contains(ShellHookInstaller.startMarker))
        XCTAssertTrue(contents.contains(" export 2>/dev/null"))
        XCTAssertTrue(contents.contains("reloadenv()"))
        XCTAssertFalse(contents.contains("command -v loadout"))
        XCTAssertTrue(installer.isInstalled(fileURL: zshrc))
    }

    func testInstallIsIdempotent() throws {
        let installer = ShellHookInstaller()
        XCTAssertTrue(try installer.installOrUpdate(fileURL: zshrc))
        let first = try String(contentsOf: zshrc, encoding: .utf8)

        XCTAssertFalse(try installer.installOrUpdate(fileURL: zshrc))
        let second = try String(contentsOf: zshrc, encoding: .utf8)
        XCTAssertEqual(second, first)
    }

    func testInstallPreservesExistingZshrcContent() throws {
        try "export PATH=\"$HOME/bin:$PATH\"\n".write(to: zshrc, atomically: true, encoding: .utf8)

        _ = try ShellHookInstaller().installOrUpdate(fileURL: zshrc)

        let contents = try String(contentsOf: zshrc, encoding: .utf8)
        XCTAssertTrue(contents.contains("export PATH"))
        XCTAssertTrue(contents.contains(ShellHookInstaller.hookBlock))
    }

    func testInstallReplacesOldMarkedHookBlock() throws {
        let old = """
        before
        \(ShellHookInstaller.startMarker)
        old loadout export
        \(ShellHookInstaller.endMarker)
        after
        """
        try old.write(to: zshrc, atomically: true, encoding: .utf8)

        _ = try ShellHookInstaller().installOrUpdate(fileURL: zshrc)

        let contents = try String(contentsOf: zshrc, encoding: .utf8)
        XCTAssertTrue(contents.contains("before"))
        XCTAssertTrue(contents.contains("after"))
        XCTAssertFalse(contents.contains("old loadout export"))
        XCTAssertEqual(contents.components(separatedBy: ShellHookInstaller.startMarker).count, 2)
    }

    func testInstallFailsSafelyWhenExistingZshrcIsNotUtf8() throws {
        let original = Data([0xFF, 0xFE, 0xFD])
        try original.write(to: zshrc)

        XCTAssertThrowsError(try ShellHookInstaller().installOrUpdate(fileURL: zshrc))
        XCTAssertEqual(try Data(contentsOf: zshrc), original)
    }

}
