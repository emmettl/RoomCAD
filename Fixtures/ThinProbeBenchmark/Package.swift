// swift-tools-version: 6.4
import Foundation
import PackageDescription

let application = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
let package = Package(
    name: "RoomCADThinProbeBenchmark", platforms: [.macOS(.v15)],
    dependencies: [.package(path: application.path)],
    targets: [
        .executableTarget(
            name: "ThinProbeAdapter",
            dependencies: [.product(name: "AcousticCore", package: application.lastPathComponent)])
    ], swiftLanguageModes: [.v6])
