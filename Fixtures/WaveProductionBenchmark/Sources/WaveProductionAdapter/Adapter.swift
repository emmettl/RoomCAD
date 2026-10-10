import Foundation
import LinearAcoustics
import simd

@testable import AcousticCore

enum AuditError: Error { case failed(String) }
struct Run: Encodable {
    let steps: Int
    let original, shared: [[Double]]
    let originalBits, sharedBits: [[UInt64]]
}
struct Case: Encodable {
    let id: String
    let room: ShoeboxRoom
    let openings: [Opening]
    let atmosphere: Atmosphere
    let sampleRate: Int
    let topFrequency: Double
    let source: [Double]
    let receivers: [RoomPoint]
    let dimensions: [Int]
    let spacing: [Double]
    let timeStep: Double
    let inside: [UInt8]
    let faces: [Float]
    let sourceCells: [Int]
    let sourceWeights: [Float]
    let receiverCells: [Int]
    let receiverWeights: [Float]
    let velocityCells: [Int]
    let axes: [Float]
    let preparedSourceCells: [Int]
    let preparedSourceWeights: [Float]
    let runs: [Run]
}
struct Timing: Encodable {
    let topFrequency: Double
    let dimensions: [Int]
    let cellCount: Int
    let steps: Int
    let layoutSeconds, sharedPreparationSeconds, sharedInitializationSeconds: Double
    let originalSeconds, sharedSeconds: [Double]
    let sharedToOriginalMedian: Double
}
struct Report: Encodable {
    let schemaVersion = 1
    let candidate: String
    let backend = "cpu"
    let cases: [Case]
    let timings: [Timing]
}
struct Generator: Encodable {
    let settings: RoomResponseSettings
    let original, shared: [[Float]]
    let originalBits, sharedBits: [[UInt32]]
    let originalDiagnostics, sharedDiagnostics: RoomResponseDiagnostics
}

@main struct Audit {
    static func check(_ value: Bool, _ label: String) throws {
        guard value else { throw AuditError.failed(label) }
    }
    static func require<T>(_ value: T?, _ label: String) throws -> T {
        guard let value else { throw AuditError.failed(label) }
        return value
    }
    static func bits(_ values: [[Double]]) -> [[UInt64]] { values.map { $0.map(\.bitPattern) } }
    static func identity(_ slot: Int) -> UUID {
        UUID(uuidString: String(format: "10000000-0000-4000-8000-%012d", slot))!
    }
    static func vector(_ v: SIMD3<Double>) -> [Double] { [v.x, v.y, v.z] }
    static func dimensions(_ s: WaveSolver) -> [Int] { [s.cells.x, s.cells.y, s.cells.z] }
    static func write<T: Encodable>(_ value: T, _ name: String, _ output: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: output.appendingPathComponent(name))
    }
    static func total(
        _ s: WaveSolver, _ source: SIMD3<Double>, _ r: [(position: SIMD3<Double>, microphone: Microphone)],
        _ steps: Int
    ) throws -> (Double, [[Double]]) {
        let clock = ContinuousClock()
        let start = clock.now
        let result = try require(
            s.simulate(source: source, receivers: r, steps: steps, stop: { false }), "simulation")
        let duration = start.duration(to: clock.now).components
        return (Double(duration.seconds) + Double(duration.attoseconds) / 1e18, result)
    }
    static func main() throws {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--output"), flag + 1 < args.count else {
            throw AuditError.failed("--output required")
        }
        let output = URL(fileURLWithPath: args[flag + 1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let candidate = ProcessInfo.processInfo.environment["ROOMCAD_PRODUCTION_REVISION"] ?? "local-debug"
        let size: SIMD3<Double> = [3, 2, 1.5]
        let plan = FloorPlan.lShape([3, 2], notch: [1, 0.7], material: .uniform(0.2, name: "Side"))
        var rigid = ShoeboxRoom(size: size, material: .rigid)
        rigid.plan = .rectangle([3, 2], material: .rigid)
        var lossy = ShoeboxRoom(size: size, material: .uniform(0.3, name: "Surface"))
        lossy.plan = .rectangle([3, 2], material: .uniform(0.2, name: "Sides"))
        lossy.plan!.walls[1] = .uniform(0.7, name: "East")
        var masked = ShoeboxRoom(size: size, material: .rigid)
        masked.plan = plan
        let tilted = FloorPlan(
            corners: [[0.1, 0.1], [2.9, 0.35], [2.6, 1.9], [0.35, 1.7]],
            walls: [.rigid, .uniform(0.1, name: "A"), .uniform(0.6, name: "B"), .rigid])
        var tiltPlan = ShoeboxRoom(size: size, material: .rigid)
        tiltPlan.plan = tilted
        var tiltMesh = ShoeboxRoom(size: size, material: .rigid)
        tiltMesh.mesh = .extruding(tilted, height: 1.5, floor: .rigid, ceiling: .rigid)
        tiltMesh.mesh!.faces[1].open = true
        var thin = ShoeboxRoom(size: [3, 2, 0.1], material: .rigid)
        thin.plan = .rectangle([3, 2], material: .uniform(0.2, name: "Thin"))
        let specs: [(String, ShoeboxRoom, SIMD3<Double>)] = [
            ("rigid-plan", rigid, [0.7, 0.5, 0.8]),
            ("lossy-open-plan", lossy, [0.7, 0.5, 0.8]),
            ("masked-L", masked, [0.7, 0.5, 0.8]),
            ("tilted-plan", tiltPlan, [0.7, 0.5, 0.8]),
            ("tilted-mesh", tiltMesh, [0.7, 0.5, 0.8]),
            ("thin-plan", thin, [0.7, 0.5, 0.05]),
            ("padded-inactive", masked, [1.99, 1.31, 0.8]),
            ("padded-nearest", masked, [2.9, 1.9, 0.8]),
        ]
        var cases: [Case] = []
        for (scene, (id, room, source)) in specs.enumerated() {
            var s = WaveSolver(
                room: room, sampleRate: 48_000, topFrequency: 180, atmosphere: .standard,
                openings: id == "lossy-open-plan"
                    ? [
                        Opening(
                            id: identity(2000), name: "Door", surface: .west, wall: 3, centre: [0.65, 0.65],
                            size: [0.7, 0.9])
                    ] : [])
            s.engine = .cpu
            let microphones =
                id == "thin-plan"
                ? [Microphone.omni, .omni]
                : Microphone.Pattern.allCases.enumerated().map {
                    Microphone(
                        pattern: $0.element, azimuth: Double($0.offset) * 31 - 47,
                        elevation: Double($0.offset) * 7 - 19)
                }
            let r = microphones.enumerated().map {
                (
                    position: SIMD3<Double>(
                        $0.offset % 2 == 0 ? 1.1 : 1.9, 0.6, id == "thin-plan" ? 0.05 : 0.8),
                    microphone: $0.element
                )
            }
            let layout = s.gridLayout(source: source, receivers: r)
            let prepared = try SharedWavePreparation(solver: s, layout: layout, receivers: r)
            var runs: [Run] = []
            for steps in [0, 1, 63, 64, 65, 127, 128, 129, 257] {
                let original = try require(
                    s.simulate(source: source, receivers: r, steps: steps, stop: { false }), id)
                let shared = try require(
                    s.usingSharedMaskedCPU().simulate(
                        source: source, receivers: r, steps: steps, stop: { false }), id)
                try check(bits(original) == bits(shared), id + " bit parity")
                try check(shared.count == r.count && shared.allSatisfy { $0.count == steps }, id + " shape")
                runs.append(
                    Run(
                        steps: steps, original: original, shared: shared, originalBits: bits(original),
                        sharedBits: bits(shared)))
            }
            cases.append(
                Case(
                    id: id, room: room, openings: s.openings, atmosphere: s.atmosphere,
                    sampleRate: s.sampleRate, topFrequency: s.topFrequency, source: vector(source),
                    receivers: r.enumerated().map {
                        RoomPoint(
                            id: identity(1000 + scene * 10 + $0.offset), name: "R\($0.offset)",
                            position: $0.element.position,
                            microphone: $0.element.microphone)
                    }, dimensions: dimensions(s), spacing: vector(s.spacing), timeStep: s.timeStep,
                    inside: layout.inside, faces: layout.faces, sourceCells: layout.sourceCells,
                    sourceWeights: layout.sourceWeights, receiverCells: layout.receiverCells,
                    receiverWeights: layout.receiverWeights, velocityCells: layout.velocityCells,
                    axes: layout.axes, preparedSourceCells: prepared.source.cellIndices,
                    preparedSourceWeights: prepared.source.coefficients, runs: runs))
        }
        var timings: [Timing] = []
        for frequency in [100.0, 200.0, 450.0] {
            var room = ShoeboxRoom(size: [8, 6, 3], material: .uniform(0.2, name: "Walls"))
            room.plan = .rectangle([8, 6], material: .uniform(0.2, name: "Walls"))
            let s = WaveSolver(room: room, sampleRate: 48_000, topFrequency: frequency, atmosphere: .standard)
            let source: SIMD3<Double> = [2, 2, 1]
            let r: [(position: SIMD3<Double>, microphone: Microphone)] = [
                (position: SIMD3<Double>(5, 3, 1.2), microphone: Microphone.omni),
                ([5.1, 3, 1.2], Microphone(pattern: .cardioid, azimuth: 153, elevation: 13)),
            ]
            let clock = ContinuousClock()
            func seconds(_ start: ContinuousClock.Instant) -> Double {
                let d = start.duration(to: clock.now).components
                return Double(d.seconds) + Double(d.attoseconds) / 1e18
            }
            var start = clock.now
            let layout = s.gridLayout(source: source, receivers: r)
            let layoutTime = seconds(start)
            start = clock.now
            let prepared = try SharedWavePreparation(solver: s, layout: layout, receivers: r)
            let preparationTime = seconds(start)
            start = clock.now
            let initialized = try CPUWaveStepper(grid: prepared.grid, initialFields: prepared.zeroFields)
            let initializationTime = seconds(start)
            try check(initialized.pressureStepIndex == 0, "initialization")
            _ = try total(s, source, r, 64)
            _ = try total(s.usingSharedMaskedCPU(), source, r, 64)
            var originalTimes: [Double] = []
            var sharedTimes: [Double] = []
            for repetition in 0..<3 {
                let a: (Double, [[Double]])
                let b: (Double, [[Double]])
                if repetition % 2 == 0 {
                    a = try total(s, source, r, 1024)
                    b = try total(s.usingSharedMaskedCPU(), source, r, 1024)
                } else {
                    b = try total(s.usingSharedMaskedCPU(), source, r, 1024)
                    a = try total(s, source, r, 1024)
                }
                try check(bits(a.1) == bits(b.1), "timing run complete parity")
                originalTimes.append(a.0)
                sharedTimes.append(b.0)
            }
            timings.append(
                Timing(
                    topFrequency: frequency, dimensions: dimensions(s), cellCount: layout.count, steps: 1024,
                    layoutSeconds: layoutTime, sharedPreparationSeconds: preparationTime,
                    sharedInitializationSeconds: initializationTime, originalSeconds: originalTimes,
                    sharedSeconds: sharedTimes,
                    sharedToOriginalMedian: sharedTimes.sorted()[1] / originalTimes.sorted()[1]))
        }
        try write(Report(candidate: candidate, cases: cases, timings: timings), "cpu-production.json", output)
        let settings = RoomResponseSettings(
            room: masked, source: RoomPoint(id: identity(3000), name: "S", position: [0.7, 0.5, 0.8]),
            receivers: [
                RoomPoint(id: identity(3001), name: "Omni", position: [1.1, 0.6, 0.8]),
                RoomPoint(
                    id: identity(3002), name: "Directional", position: [1.9, 0.6, 0.8],
                    microphone: Microphone(pattern: .cardioid, azimuth: 137, elevation: 23)),
            ], duration: 0.05, maximumReflectionOrder: 1, lowFrequencyModel: true, crossoverFrequency: 80)
        let a = try RoomResponseGenerator.generate(
            settings,
            configureWaveSolver: {
                var s = $0
                s.engine = .cpu
                return s
            })
        let b = try RoomResponseGenerator.generate(
            settings,
            configureWaveSolver: {
                var s = $0.usingSharedMaskedCPU()
                s.engine = .cpu
                return s
            })
        let ab = a.response.channels.map { $0.map(\.bitPattern) }
        let bb = b.response.channels.map { $0.map(\.bitPattern) }
        try check(ab == bb && a.settings == b.settings, "complete generator")
        var da = a.diagnostics
        var db = b.diagnostics
        da.generationSeconds = 0
        db.generationSeconds = 0
        da.waveSeconds = 0
        db.waveSeconds = 0
        try check(
            da == db && (da.waveRuns ?? 0) > 0 && da.waveGPURuns == 0,
            "complete non-timing diagnostics and actual CPU wave runs")
        try write(
            Generator(
                settings: settings, original: a.response.channels, shared: b.response.channels,
                originalBits: ab, sharedBits: bb, originalDiagnostics: a.diagnostics,
                sharedDiagnostics: b.diagnostics), "generator.json", output)
        for (name, response) in [("original", a), ("shared", b)] {
            let data = try response.encoded()
            try data.wav.write(to: output.appendingPathComponent(name + ".wav"))
            try data.metadata.write(to: output.appendingPathComponent(name + "-metadata.json"))
            let reopened = try RoomResponse(wav: data.wav, metadata: data.metadata)
            try check(
                reopened.settings == settings
                    && reopened.response.channels.map { $0.map(\.bitPattern) } == bb, "saved response")
        }
        print("PASS complete production CPU comparisons, timing repetitions and generator/save controls")
    }
}
