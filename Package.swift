// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RoomCAD",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AcousticModel", targets: ["AcousticModel"]),
        .library(name: "AuditionDSP", targets: ["AuditionDSP"]),
        .library(name: "AcousticCore", targets: ["AcousticCore"]),
        .library(name: "RoomDocument", targets: ["RoomDocument"]),
        .library(name: "Audition", targets: ["Audition"]),
        .executable(name: "RoomCAD", targets: ["RoomCAD"]),
        .executable(name: "acousticbench", targets: ["acousticbench"]),
    ],
    dependencies: [.package(url: "https://github.com/emmettl/ContinuumKit.git", exact: "0.1.0-alpha.29")],
    targets: [
        .target(
            name: "AcousticModel",
            dependencies: [
                .product(name: "SceneModel", package: "continuumkit"),
                .product(name: "ImpulseResponseKit", package: "continuumkit"),
                .product(name: "SpectralTransforms", package: "continuumkit"),
                .product(name: "Numerics", package: "continuumkit"),
            ]),
        .target(
            name: "AuditionDSP",
            dependencies: ["AcousticModel", .product(name: "ImpulseResponseKit", package: "continuumkit")]),
        .target(
            name: "AcousticCore",
            dependencies: [
                "AcousticModel",
                .product(name: "SceneModel", package: "continuumkit"),
                .product(name: "ImpulseResponseKit", package: "continuumkit"),
                .product(name: "SpectralTransforms", package: "continuumkit"),
                .product(name: "Numerics", package: "continuumkit"),
                .product(name: "LinearAcoustics", package: "continuumkit"),
                .product(name: "LinearAcousticsMetal", package: "continuumkit"),
            ],
            // Original reference consumers copy this source into their frozen manifests.
            swiftSettings: [.define("ROOMCAD_SHARED_WAVE_DEFAULT")]),
        .target(
            name: "RoomDocument",
            dependencies: [
                "AcousticModel", .product(name: "ImpulseResponseKit", package: "continuumkit"),
                .product(name: "DocumentKit", package: "continuumkit"),
            ]),
        // Bundled dry recordings are listed, with their credits, in Clips/clips.json.
        .target(
            name: "Audition",
            dependencies: ["AuditionDSP", .product(name: "ImpulseResponseKit", package: "continuumkit")],
            resources: [.copy("Clips")]),
        .executableTarget(
            name: "RoomCAD",
            dependencies: [
                "AcousticCore", "AcousticModel",
                .product(name: "ImpulseResponseKit", package: "continuumkit"), "RoomDocument",
                "Audition",
                .product(name: "DocumentKit", package: "continuumkit"),
                .product(name: "SceneModel", package: "continuumkit"),
                .product(name: "SceneView", package: "continuumkit"),
                .product(name: "SceneRender", package: "continuumkit"),
                .product(name: "GeometryImport", package: "continuumkit"),
            ]),
        .executableTarget(
            name: "acousticbench",
            dependencies: [
                "AcousticCore", "AcousticModel",
                .product(name: "ImpulseResponseKit", package: "continuumkit"), "Audition",
            ]),
        .testTarget(
            name: "AuditionDSPTests",
            dependencies: [
                "AuditionDSP", "AcousticModel", .product(name: "ImpulseResponseKit", package: "continuumkit"),
            ]),
        .testTarget(
            name: "AcousticModelTests",
            dependencies: ["AcousticModel", .product(name: "ImpulseResponseKit", package: "continuumkit")]),
        .testTarget(
            name: "AcousticCoreTests",
            dependencies: [
                "AcousticCore", "AcousticModel",
                .product(name: "ImpulseResponseKit", package: "continuumkit"),
                .product(name: "LinearAcoustics", package: "continuumkit"),
                .product(name: "LinearAcousticsMetal", package: "continuumkit"),
            ]),
        .testTarget(
            name: "RoomDocumentTests",
            dependencies: [
                "RoomDocument", "AcousticCore", "AcousticModel",
                .product(name: "ImpulseResponseKit", package: "continuumkit"),
                .product(name: "DocumentKit", package: "continuumkit"),
            ]),
        .testTarget(
            name: "AuditionTests",
            dependencies: [
                "Audition", "AuditionDSP", "AcousticCore", "AcousticModel",
                .product(name: "ImpulseResponseKit", package: "continuumkit"),
            ]),
        .testTarget(
            name: "RoomCADTests",
            dependencies: [
                "RoomCAD", "RoomDocument", "AcousticCore",
                .product(name: "SceneRender", package: "continuumkit"),
                .product(name: "SceneView", package: "continuumkit"),
            ]),
    ],
    swiftLanguageModes: [.v6]
)

// Linux builds the model, CPU generation, document/interchange, audition DSP and CLI.
// Apple UI, recording decoding and Metal keep their existing target/resource identities.
#if os(Linux)
    let appleTargets: Set<String> = ["RoomCAD", "RoomCADTests", "Audition", "AuditionTests"]
    package.targets.removeAll { appleTargets.contains($0.name) }
    package.products.removeAll { appleTargets.contains($0.name) }
    for target in package.targets {
        target.dependencies.removeAll {
            if case .product(let name, _, _, _) = $0 { return name == "LinearAcousticsMetal" }
            if case .byName(let name, _) = $0 { return name == "Audition" }
            return false
        }
        if target.name == "AcousticCore" { target.exclude += ["SharedMetalSimulation.swift"] }
        if target.name == "AcousticCoreTests" {
            target.exclude += [
                "OriginalMetalWaveSolver.swift", "SharedMetalSimulationTests.swift",
                "ThinDirectionalProbeTests.swift",
            ]
        }
        if target.name == "acousticbench" { target.dependencies.append("AuditionDSP") }
    }
#endif
