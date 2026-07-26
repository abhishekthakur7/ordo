// swift-tools-version: 6.0
import PackageDescription

let swiftSettings: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "Ordo",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OrdoCore", targets: ["OrdoCore"]),
        .library(name: "OrdoThemes", targets: ["OrdoThemes"]),
        .library(name: "OrdoSound", targets: ["OrdoSound"]),
        .library(name: "OrdoUI", targets: ["OrdoUI"]),
        .executable(name: "OrdoApp", targets: ["OrdoApp"]),
    ],
    targets: [
        .target(name: "OrdoCore", swiftSettings: swiftSettings),
        .target(name: "OrdoThemes", dependencies: ["OrdoCore"], swiftSettings: swiftSettings),
        .target(name: "OrdoSound", dependencies: ["OrdoCore", "OrdoThemes"], swiftSettings: swiftSettings),
        .target(name: "OrdoUI", dependencies: ["OrdoCore", "OrdoThemes"], swiftSettings: swiftSettings),
        .executableTarget(
            name: "OrdoApp",
            dependencies: ["OrdoCore", "OrdoThemes", "OrdoSound", "OrdoUI"],
            swiftSettings: swiftSettings
        ),
        .testTarget(name: "OrdoCoreTests", dependencies: ["OrdoCore"], swiftSettings: swiftSettings),
        .testTarget(name: "OrdoThemesTests", dependencies: ["OrdoThemes"], swiftSettings: swiftSettings),
        .testTarget(name: "OrdoSoundTests", dependencies: ["OrdoSound"], swiftSettings: swiftSettings),
        .testTarget(name: "OrdoUITests", dependencies: ["OrdoUI"], swiftSettings: swiftSettings),
    ]
)
