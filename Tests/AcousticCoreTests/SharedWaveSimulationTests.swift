import Foundation
import Synchronization
import Testing
import simd

@testable import AcousticCore

@Suite("Shared production masked CPU binding")
struct SharedWaveSimulationTests {
    private let positions: [SIMD3<Double>] = [[1.1, 0.7, 0.6], [1.9, 0.6, 0.8], [1.1, 0.7, 0.6]]
    private var receivers: [(position: SIMD3<Double>, microphone: Microphone)] {
        [
            (positions[0], .omni),
            (positions[1], Microphone(pattern: .cardioid, azimuth: 137, elevation: 23)),
            (positions[2], Microphone(pattern: .figureOfEight, azimuth: -41, elevation: -17)),
        ]
    }
    private func solver(mesh: Bool = false) -> WaveSolver {
        let plan = FloorPlan.lShape([3, 2], notch: [1, 0.7], material: .uniform(0.2, name: "Wall"))
        var room = ShoeboxRoom(size: [3, 2, 1.5], material: .rigid)
        if mesh {
            room.mesh = .extruding(plan, height: 1.5, floor: .rigid, ceiling: .rigid)
        } else {
            room.plan = plan
        }
        var solver = WaveSolver(
            room: room, sampleRate: 48_000, topFrequency: 180, atmosphere: .standard)
        solver.engine = .cpu
        return solver.usingOriginalMaskedCPU()
    }
    @Test("Large application grids use the original slab policy and retain full microphone output")
    func parallelApplication() throws {
        var room = ShoeboxRoom(size: [6, 4, 3], material: .uniform(0.2, name: "Wall"))
        room.plan = .rectangle([6, 4], material: .uniform(0.2, name: "Wall"))
        let s = WaveSolver(room: room, sampleRate: 48_000, topFrequency: 200, atmosphere: .standard)
        #expect(s.cells.x * s.cells.y * s.cells.z >= 4_096 && s.cells.z > 1)
        let oldResult = s.usingOriginalMaskedCPU().simulate(
            source: [0.7, 0.5, 0.8], receivers: receivers, steps: 257, stop: { false })
        let newResult = s.usingSharedMaskedCPU().simulate(
            source: [0.7, 0.5, 0.8], receivers: receivers, steps: 257, stop: { false })
        let old = try #require(oldResult)
        let new = try #require(newResult)
        #expect(bits(old) == bits(new))
    }

    @Test("Application default selects shared masked CPU and explicit original control stays available")
    func defaultSelection() throws {
        let legacy = solver()
        let current = WaveSolver(
            room: legacy.room, sampleRate: legacy.sampleRate,
            topFrequency: legacy.topFrequency, atmosphere: legacy.atmosphere)
        #expect(current.maskedCPUBackend is SharedMaskedCPUSimulation)
        #expect(current.usingOriginalMaskedCPU().maskedCPUBackend is OriginalMaskedCPUSimulation)
        let aResult = current.usingOriginalMaskedCPU().simulate(
            source: [0.7, 0.5, 0.8], receivers: receivers, steps: 257, stop: { false })
        let bResult = current.simulate(
            source: [0.7, 0.5, 0.8], receivers: receivers, steps: 257, stop: { false })
        #expect(bits(try #require(aResult)) == bits(try #require(bResult)))
    }

    private func bits(_ signals: [[Double]]) -> [[UInt64]] { signals.map { $0.map(\.bitPattern) } }

    @Test(
        "Whole real plan/mesh microphone outputs match at every batch edge",
        arguments: [0, 1, 63, 64, 65, 127, 128, 129, 257])
    func outputs(steps: Int) throws {
        for mesh in [false, true] {
            let original = solver(mesh: mesh)
            let aResult =
                original.simulate(
                    source: [0.7, 0.5, 0.8], receivers: receivers, steps: steps, stop: { false })
            let a = try #require(aResult)
            let bResult =
                original.usingSharedMaskedCPU().simulate(
                    source: [0.7, 0.5, 0.8], receivers: receivers, steps: steps, stop: { false })
            let b = try #require(bResult)
            #expect(bits(a) == bits(b))
            #expect(b.count == receivers.count && b.allSatisfy { $0.count == steps })
        }
    }

    @Test("Inactive source zeros and repeated nearest-cell padding preserve outputs")
    func padding() throws {
        let s = solver()
        let sources: [SIMD3<Double>] = [[1.99, 1.31, 0.8], [2.9, 1.9, 0.8]]
        for source in sources {
            let layout = s.gridLayout(source: source, receivers: receivers)
            #expect(
                zip(layout.sourceCells, layout.sourceWeights).contains {
                    layout.inside[$0.0] == 0 || $0.1 == 0
                })
            let aResult =
                s.simulateMasked(source: source, receivers: receivers, steps: 257, stop: { false })
            let a = try #require(aResult)
            let bResult =
                SharedMaskedCPUSimulation().simulate(
                    s, source: source, receivers: receivers, steps: 257, stop: { false })
            let b = try #require(bResult)
            #expect(bits(a) == bits(b))
        }
    }

    @Test("Malformed layout and nonzero padding reject before unsafe address access")
    func invalidPreparation() throws {
        let s = solver()
        let layout = s.gridLayout(source: [0.7, 0.5, 0.8], receivers: receivers)
        _ = try SharedWavePreparation(solver: s, layout: layout, receivers: receivers)
        var short = layout
        short.sourceWeights.removeLast()
        var outside = layout
        outside.sourceCells[0] = layout.count
        var duplicate = layout
        duplicate.sourceCells[1] = duplicate.sourceCells[0]
        duplicate.sourceWeights[1] = 1
        var inactive = layout
        inactive.sourceCells[0] = try #require(layout.inside.firstIndex(of: 0))
        inactive.sourceWeights[0] = 1
        var badReceiver = layout
        badReceiver.receiverCells[0] = layout.count
        for rejected in [short, outside, duplicate, inactive, badReceiver] {
            #expect(throws: (any Error).self) {
                try SharedWavePreparation(solver: s, layout: rejected, receivers: receivers)
            }
        }
    }

    @Test(
        "Cancellation occurs exactly before the original 64-step boundaries",
        arguments: [0, 1, 64, 65, 128, 129, 257])
    func cancellation(steps: Int) {
        let s = solver()
        let calls = steps == 0 ? 0 : (steps + 63) / 64
        for cancelledAt in 1...max(calls + 1, 1) {
            let oldCalls = Mutex(0)
            let newCalls = Mutex(0)
            let a = s.simulate(source: [0.7, 0.5, 0.8], receivers: receivers, steps: steps) {
                oldCalls.withLock {
                    $0 += 1
                    return $0 == cancelledAt
                }
            }
            let b = s.usingSharedMaskedCPU().simulate(
                source: [0.7, 0.5, 0.8], receivers: receivers, steps: steps
            ) {
                newCalls.withLock {
                    $0 += 1
                    return $0 == cancelledAt
                }
            }
            #expect(oldCalls.withLock { $0 } == newCalls.withLock { $0 })
            #expect((a == nil) == (b == nil))
            if let a, let b { #expect(bits(a) == bits(b)) }
        }
    }

    @Test("Shared selection leaves the optimized unmasked box path intact")
    func unmasked() throws {
        let s = WaveSolver(
            room: ShoeboxRoom(size: [3, 2, 1.5], material: .rigid), sampleRate: 48_000, topFrequency: 180,
            atmosphere: .standard)
        let aResult =
            s.simulate(source: [0.7, 0.5, 0.8], receivers: receivers, steps: 129, stop: { false })
        let a = try #require(aResult)
        let bResult =
            s.usingSharedMaskedCPU().simulate(
                source: [0.7, 0.5, 0.8], receivers: receivers, steps: 129, stop: { false })
        let b = try #require(bResult)
        #expect(bits(a) == bits(b))
    }

    @Test("Complete response spectra, octave grouping and diffuse correction stay exact")
    func responses() throws {
        let s = solver()
        let aResult =
            s.responses(
                source: [0.7, 0.5, 0.8], receivers: receivers, frames: 512, fftLength: 2048,
                weight: { f in f < 200 ? 1 : 0 }, stop: { false })
        let a = try #require(aResult)
        let bResult =
            s.usingSharedMaskedCPU().responses(
                source: [0.7, 0.5, 0.8], receivers: receivers, frames: 512, fftLength: 2048,
                weight: { f in f < 200 ? 1 : 0 }, stop: { false })
        let b = try #require(bResult)
        #expect(a.channels.map { $0.map(\.bitPattern) } == b.channels.map { $0.map(\.bitPattern) })
        #expect(a.gpuRuns == 0 && b.gpuRuns == 0)
        #expect(Set(a.decay.keys) == Set(b.decay.keys))
        for key in a.decay.keys {
            #expect(a.decay[key]?.bare == b.decay[key]?.bare)
            #expect(a.decay[key]?.diffuse == b.decay[key]?.diffuse)
        }
    }

    @Test("Full generator retains channels, saved settings and all non-timing diagnostics")
    func generator() throws {
        let s = solver()
        let settings = RoomResponseSettings(
            room: s.room, source: RoomPoint(name: "Source", position: [0.7, 0.5, 0.8]),
            receivers: receivers.enumerated().map {
                RoomPoint(
                    name: "R\($0.offset)", position: $0.element.position, microphone: $0.element.microphone)
            }, duration: 0.05, maximumReflectionOrder: 1, lowFrequencyModel: true, crossoverFrequency: 80)
        let a = try RoomResponseGenerator.generate(
            settings,
            configureWaveSolver: { solver in
                var copy = solver.usingOriginalMaskedCPU()
                copy.engine = .cpu
                return copy
            })
        let b = try RoomResponseGenerator.generate(
            settings,
            configureWaveSolver: { solver in
                var copy = solver.usingSharedMaskedCPU()
                copy.engine = .cpu
                return copy
            })
        #expect(
            a.response.channels.map { $0.map(\.bitPattern) }
                == b.response.channels.map { $0.map(\.bitPattern) })
        #expect(a.settings == b.settings)
        #expect((a.diagnostics.waveRuns ?? 0) > 0 && a.diagnostics.waveGPURuns == 0)
        #expect((b.diagnostics.waveRuns ?? 0) > 0 && b.diagnostics.waveGPURuns == 0)
        var da = a.diagnostics
        var db = b.diagnostics
        da.generationSeconds = 0
        db.generationSeconds = 0
        da.waveSeconds = 0
        db.waveSeconds = 0
        #expect(da == db)
        let encoded = try b.encoded()
        let saved = try RoomResponse(wav: encoded.wav, metadata: encoded.metadata)
        #expect(saved.settings == settings)
        #expect(
            saved.response.channels.map { $0.map(\.bitPattern) }
                == b.response.channels.map { $0.map(\.bitPattern) })
    }

    @Test("Concurrent calls own independent fields, histories and lookahead")
    func concurrent() throws {
        let s = solver().usingSharedMaskedCPU()
        let r = receivers
        let expectedResult =
            s.simulate(source: [0.7, 0.5, 0.8], receivers: r, steps: 257, stop: { false })
        let expected = try #require(expectedResult)
        let results = Mutex([[[Double]]?](repeating: nil, count: 4))
        DispatchQueue.concurrentPerform(iterations: 4) { i in
            let source: SIMD3<Double> = i == 3 ? [1.5, 0.3, 0.7] : [0.7, 0.5, 0.8]
            let values = s.simulate(source: source, receivers: r, steps: 257, stop: { false })
            results.withLock { $0[i] = values }
        }
        let values = results.withLock { $0 }
        for i in 0..<3 { #expect(bits(try #require(values[i])) == bits(expected)) }
        #expect(bits(try #require(values[3])) != bits(expected))
    }

    @Test("Thin pressure-only grids and empty outputs avoid unused velocity access")
    func thin() throws {
        var room = ShoeboxRoom(size: [3, 2, 0.1], material: .rigid)
        room.plan = .rectangle([3, 2], material: .rigid)
        let s = WaveSolver(room: room, sampleRate: 48_000, topFrequency: 180, atmosphere: .standard)
        #expect(s.cells.z == 2)
        let r = [(position: SIMD3<Double>(1.1, 0.7, 0.05), microphone: Microphone.omni)]
        let aResult = s.usingOriginalMaskedCPU().simulate(
            source: [0.7, 0.5, 0.05], receivers: r, steps: 129, stop: { false })
        let a = try #require(aResult)
        let bResult =
            s.usingSharedMaskedCPU().simulate(
                source: [0.7, 0.5, 0.05], receivers: r, steps: 129, stop: { false })
        let b = try #require(bResult)
        #expect(bits(a) == bits(b))
        let empty = s.usingSharedMaskedCPU().simulate(
            source: [0.7, 0.5, 0.05], receivers: [], steps: 129, stop: { false })
        #expect(empty == [])
        let directional = [(position: r[0].position, microphone: Microphone(pattern: .cardioid))]
        let original = s.usingOriginalMaskedCPU().simulate(
            source: [0.7, 0.5, 0.05], receivers: directional, steps: 129, stop: { false })
        let shared = s.usingSharedMaskedCPU().simulate(
            source: [0.7, 0.5, 0.05], receivers: directional, steps: 129, stop: { false })
        #expect(bits(try #require(original)) == bits(try #require(shared)))
    }
}
