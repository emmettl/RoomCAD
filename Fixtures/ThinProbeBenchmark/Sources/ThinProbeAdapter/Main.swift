import Foundation
import Metal
import simd

@testable import AcousticCore

struct Run: Encodable {
    let steps: Int
    let cpu, shared, metal: [[Double]]
    let cpuBits, sharedBits, metalBits: [[UInt64]]
}
struct Scene: Encodable {
    let axis: Int, representation: String
    let size, source, receiver, spacing: [Double]
    let dimensions, probeCell: [Int]
    let timeStep, speed, volume: Double
    let inside: [UInt8], faces: [Float]
    let sourceCells: [Int], sourceWeights: [Float], pressureCells: [Int], pressureWeights: [Float]
    let velocityCells: [Int], axes: [Float]
    let microphones: [Microphone]
    let expectedCPUFirst, expectedCPULast, expectedMetalFirst, expectedMetalLast: [Double]
    let runs: [Run]
}
struct Report: Encodable {
    let candidate, device: String
    let scenes: [Scene]
}
enum Failure: Error { case badInput, missingBackend, mismatch }
@main struct Main {
    static func v(_ x: SIMD3<Double>) -> [Double] { [x.x, x.y, x.z] }
    static func bits(_ x: [[Double]]) -> [[UInt64]] { x.map { $0.map(\.bitPattern) } }
    static func require<T>(_ value: T?) throws -> T {
        guard let value else { throw Failure.missingBackend }
        return value
    }
    static func main() throws {
        guard let flag = CommandLine.arguments.firstIndex(of: "--output"),
            flag + 1 < CommandLine.arguments.count
        else { throw Failure.badInput }
        let output = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let gpu = try require(MetalWaveSolver.shared)
        var scenes: [Scene] = []
        for axis in 0..<3 {
            for representation in ["box", "plan", "mesh"] {
                var size = SIMD3<Double>(repeating: 4)
                size[axis] = 1
                var room = ShoeboxRoom(size: size, material: .rigid)
                if representation == "plan" { room.plan = .rectangle([size.x, size.y], material: .rigid) }
                if representation == "mesh" {
                    room.mesh = .box(
                        size,
                        materials: Dictionary(
                            uniqueKeysWithValues: Surface.allCases.map { ($0, SurfaceMaterial.rigid) }))
                }
                let s = WaveSolver(
                    room: room, sampleRate: 48_000,
                    topFrequency: Atmosphere.standard.soundSpeed / 10 * (1 - 1e-9), atmosphere: .standard)
                var source = s.spacing * SIMD3<Double>(repeating: 1.5)
                source[axis] = s.spacing[axis] / 2
                var receiver = source
                receiver[axis] = 1.5 * s.spacing[axis]
                let microphones = Microphone.Pattern.allCases.map {
                    Microphone(pattern: $0, azimuth: axis == 1 ? 90 : 0, elevation: axis == 2 ? 90 : 0)
                }
                let r = microphones.map { (position: receiver, microphone: $0) }
                let layout = s.gridLayout(source: source, receivers: r)
                let probe = s.velocityProbeCell(receiver)
                guard s.cells[axis] == 2, probe[axis] == 1 else { throw Failure.mismatch }
                let c = s.atmosphere.soundSpeed
                let dt = s.timeStep
                let h = s.spacing[axis]
                let volume = s.spacing.x * s.spacing.y * s.spacing.z
                let q = s.pulse(0.5 * dt)
                let initialCPU =
                    representation == "box"
                    ? Float(c * c * dt * q / volume) : Float(q) * Float(c * c * dt / volume)
                let cpuFace = Float(dt / h) * initialCPU
                let cpuPressure = Float(c * c * dt / h) * cpuFace
                let initialMetal = Float(q) * Float(c * c * dt / volume)
                let metalFace = Float(dt / h) * initialMetal
                let metalPressure = Float(c * c * dt / h) * metalFace
                let firstCPU = microphones.map { -(1 - $0.pattern.omniShare) * c * (Double(cpuFace) / 4) }
                let lastCPU = microphones.map {
                    $0.pattern.omniShare * Double(cpuPressure) - (1 - $0.pattern.omniShare) * c
                        * (Double(cpuFace) / 2)
                }
                let firstMetal = microphones.map {
                    -(1 - $0.pattern.omniShare) * c * (Double(metalFace / 2) / 2)
                }
                let lastMetal = microphones.map {
                    $0.pattern.omniShare * Double(metalPressure) - (1 - $0.pattern.omniShare) * c
                        * Double(metalFace / 2)
                }
                var runs: [Run] = []
                for steps in [0, 1, 2, 63, 64, 65, 127, 128, 129, 257] {
                    let cpu = try require(
                        s.usingOriginalMaskedCPU().simulate(
                            source: source, receivers: r, steps: steps, stop: { false }))
                    let shared = try require(
                        s.usingSharedMaskedCPU().simulate(
                            source: source, receivers: r, steps: steps, stop: { false }))
                    let metal = try require(
                        gpu.simulate(s, source: source, receivers: r, steps: steps, stop: { false }))
                    guard bits(cpu) == bits(shared), cpu.allSatisfy({ $0.count == steps }),
                        metal.allSatisfy({ $0.count == steps })
                    else { throw Failure.mismatch }
                    if steps == 2 {
                        for i in microphones.indices {
                            for (actual, expected) in [
                                (cpu[i][0], firstCPU[i]), (cpu[i][1], lastCPU[i]),
                                (metal[i][0], firstMetal[i]), (metal[i][1], lastMetal[i]),
                            ] {
                                guard abs(actual - expected) <= 1e-6 * max(abs(expected), 1e-15) else {
                                    throw Failure.mismatch
                                }
                            }
                        }
                    }
                    runs.append(
                        Run(
                            steps: steps, cpu: cpu, shared: shared, metal: metal, cpuBits: bits(cpu),
                            sharedBits: bits(shared), metalBits: bits(metal)))
                }
                scenes.append(
                    Scene(
                        axis: axis, representation: representation, size: v(size), source: v(source),
                        receiver: v(receiver), spacing: v(s.spacing),
                        dimensions: [s.cells.x, s.cells.y, s.cells.z],
                        probeCell: [probe.x, probe.y, probe.z], timeStep: dt, speed: c, volume: volume,
                        inside: layout.inside, faces: layout.faces, sourceCells: layout.sourceCells,
                        sourceWeights: layout.sourceWeights, pressureCells: layout.receiverCells,
                        pressureWeights: layout.receiverWeights, velocityCells: layout.velocityCells,
                        axes: layout.axes, microphones: microphones, expectedCPUFirst: firstCPU,
                        expectedCPULast: lastCPU, expectedMetalFirst: firstMetal,
                        expectedMetalLast: lastMetal, runs: runs))
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let report = Report(
            candidate: ProcessInfo.processInfo.environment["ROOMCAD_PRODUCTION_REVISION"] ?? "local-debug",
            device: gpu.device.name, scenes: scenes)
        try encoder.encode(report).write(to: output.appendingPathComponent("thin-probes.json"))
        print("PASS all-axis thin box/plan/mesh whole CPU/shared/actual-Metal streams and two-step oracle")
    }
}
