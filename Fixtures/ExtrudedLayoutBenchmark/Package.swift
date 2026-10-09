// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RoomCADExtrudedLayoutBenchmark", platforms: [.macOS(.v15)],
    dependencies: [.package(url: "https://github.com/emmettl/ContinuumKit.git", exact: "0.1.0-alpha.2")],
    targets: [
        .target(
            name: "AcousticCore",
            dependencies: [.product(name: "ImpulseResponseKit", package: "continuumkit")]),
        .executableTarget(name: "ExtrudedLayoutAdapter", dependencies: ["AcousticCore"]),
    ], swiftLanguageModes: [.v6])
