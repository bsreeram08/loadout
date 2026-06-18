import XCTest
@testable import LoadoutCore

final class PathsTests: XCTestCase {
    func testKeychainServiceEncodesServiceAndVariant() {
        XCTAssertEqual(
            LoadoutPaths.keychainService(service: "worldline", variant: "prod"),
            "loadout:worldline:prod"
        )
    }

    func testParseKeychainServiceRoundTrips() {
        let encoded = LoadoutPaths.keychainService(service: "my-svc", variant: "dev")
        let parsed = LoadoutPaths.parseKeychainService(encoded)
        XCTAssertEqual(parsed, ServiceVariant(service: "my-svc", variant: "dev"))
    }

    func testParseKeychainServiceRejectsNonLoadoutPrefix() {
        XCTAssertNil(LoadoutPaths.parseKeychainService("other:foo:bar"))
        XCTAssertNil(LoadoutPaths.parseKeychainService(""))
    }

    func testParseKeychainServiceRejectsMissingVariant() {
        XCTAssertNil(LoadoutPaths.parseKeychainService("loadout:onlyservice"))
    }

    func testStateFileURLRespectsOverride() {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadout-paths-\(UUID().uuidString).json")
        setenv("LOADOUT_STATE_PATH", temp.path, 1)
        defer { unsetenv("LOADOUT_STATE_PATH") }
        XCTAssertEqual(LoadoutPaths.stateFileURL.path, temp.path)
    }
}