// swift-tools-version: 6.4
import Foundation
import PackageDescription

let application = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
let package = Package(
    name: "RoomCADThinProbeBenchmark", platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: application.path),
        .package(url: "https://github.com/emmettl/ContinuumKit.git", exact: "0.1.0-alpha.29"),
    ],
    targets: [
        .executableTarget(
            name: "ThinProbeAdapter",
            dependencies: [
                .product(name: "AcousticModel", package: application.lastPathComponent),
                .product(name: "AcousticCore", package: application.lastPathComponent),
                .product(name: "LinearAcousticsMetal", package: "continuumkit"),
            ],
            // This verification-only executable uses the app's package-scoped model implementation.
            // Keep the immutable original numerical source files byte-identical.
            swiftSettings: [.unsafeFlags(["-package-name", "roomcad"])])
    ], swiftLanguageModes: [.v6])
