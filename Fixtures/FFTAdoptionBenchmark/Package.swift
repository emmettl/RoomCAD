// swift-tools-version: 6.4
import Foundation
import PackageDescription

let application = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
let resolved =
    try! JSONSerialization.jsonObject(
        with: Data(contentsOf: application.appendingPathComponent("Package.resolved"))) as! [String: Any]
let core = (resolved["pins"] as! [[String: Any]]).first { $0["identity"] as? String == "continuumkit" }!
let version = (core["state"] as! [String: String])["version"]!
let package = Package(
    name: "RoomCADFFTAdoptionBenchmark", platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: application.path),
        .package(url: "https://github.com/emmettl/ContinuumKit.git", exact: Version(version)!),
    ],
    targets: [
        .executableTarget(
            name: "FFTAdoptionBenchmark",
            dependencies: [
                .product(name: "AcousticCore", package: application.lastPathComponent),
                .product(name: "Audition", package: application.lastPathComponent),
                .product(name: "ImpulseResponseKit", package: "continuumkit"),
            ])
    ], swiftLanguageModes: [.v6])
