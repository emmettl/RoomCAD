// swift-tools-version: 6.4
import Foundation
import PackageDescription

let application = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
let package = Package(
    name: "RoomCADWaveMetalProductionBenchmark", platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: application.path),
        .package(url: "https://github.com/emmettl/ContinuumKit.git", exact: "0.1.0-alpha.12"),
    ],
    targets: [
        .executableTarget(
            name: "WaveMetalProductionAdapter",
            dependencies: [
                .product(name: "AcousticCore", package: application.lastPathComponent),
                .product(name: "LinearAcoustics", package: "continuumkit"),
                .product(name: "LinearAcousticsMetal", package: "continuumkit"),
            ])
    ], swiftLanguageModes: [.v6])
