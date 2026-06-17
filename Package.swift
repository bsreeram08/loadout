// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "loadout",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "loadout", targets: ["loadout"]),
        .executable(name: "LoadoutApp", targets: ["LoadoutApp"]),
        .library(name: "LoadoutCore", targets: ["LoadoutCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "LoadoutCore",
            linkerSettings: [
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .executableTarget(
            name: "loadout",
            dependencies: [
                "LoadoutCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "LoadoutApp",
            dependencies: ["LoadoutCore"],
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: "LoadoutCoreTests",
            dependencies: ["LoadoutCore"]
        ),
    ]
)