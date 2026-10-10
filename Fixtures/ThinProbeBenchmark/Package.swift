// swift-tools-version: 6.4
import Foundation
import PackageDescription

let application = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
let package = Package(
    name: "RoomCADThinProbeBenchmark", platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: application.path),
        .package(url: "https://github.com/emmettl/ContinuumKit.git", exact: "0.1.0-alpha.18"),
    ],
    targets: [
        .executableTarget(
            name: "ThinProbeAdapter",
            dependencies: [
                .product(name: "AcousticCore", package: application.lastPathComponent),
                .product(name: "LinearAcousticsMetal", package: "continuumkit"),
            ])
    ], swiftLanguageModes: [.v6])
