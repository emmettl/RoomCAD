import Foundation
import LinearAcousticsMetal
import Metal
import Synchronization
import Testing
import simd

@testable import AcousticCore

@Suite("Shared production Metal comparison binding")
struct SharedMetalSimulationTests {
    private func context() throws -> MetalWaveContext {
        try MetalWaveContext(device: #require(MTLCreateSystemDefaultDevice()))
    }
    private func solver(_ representation: Int = 1) -> WaveSolver {
        let plan = FloorPlan.lShape([3, 2], notch: [1, 0.7], material: .uniform(0.2, name: "Wall"))
        var room = ShoeboxRoom(size: [3, 2, 1.5], material: .rigid)
        if representation == 1 { room.plan = plan }
        if representation == 2 { room.mesh = .extruding(plan, height: 1.5, floor: .rigid, ceiling: .rigid) }
        return WaveSolver(room: room, sampleRate: 48_000, topFrequency: 180, atmosphere: .standard)
    }
    private var receivers: [(position: SIMD3<Double>, microphone: Microphone)] {
        Microphone.Pattern.allCases.map {
            ([1.1, 0.7, 0.6], Microphone(pattern: $0, azimuth: 137, elevation: 23))
        }
    }
    private func bits(_ v: [[Double]]) -> [[UInt64]] { v.map { $0.map(\.bitPattern) } }

    @Test("All patterns retain complete original Metal output at command and terminal boundaries")
    func output() throws {
        let old = try #require(MetalWaveSolver.shared)
        let shared = SharedMetalSimulation(context: try context())
        for representation in 0..<3 {
            let s = solver(representation)
            for steps in [0, 1, 2, 63, 64, 65, 127, 128, 129, 257] {
                let aValue =
                    old.simulate(
                        s, source: [0.7, 0.5, 0.8], receivers: receivers, steps: steps, stop: { false })
                let a = try #require(aValue)
                let bValue =
                    shared.simulate(
                        s, source: [0.7, 0.5, 0.8], receivers: receivers, steps: steps, stop: { false })
                let b = try #require(bValue)
                #expect(bits(a) == bits(b))
                #expect(b.count == 6 && b.allSatisfy { $0.count == steps })
            }
        }
    }

    @Test("Cancellation and nonterminal abandonment retain exact 128-step callback boundaries")
    func boundaries() throws {
        let old = try #require(MetalWaveSolver.shared)
        let shared = SharedMetalSimulation(context: try context())
        let s = solver()
        for steps in [0, 1, 128, 129, 256, 257] {
            for cancelledAt in 1...4 {
                let oldCalls = Mutex(0)
                let newCalls = Mutex(0)
                let a = old.simulate(s, source: [0.7, 0.5, 0.8], receivers: receivers, steps: steps) {
                    oldCalls.withLock {
                        $0 += 1
                        return $0 == cancelledAt
                    }
                }
                let b = shared.simulate(s, source: [0.7, 0.5, 0.8], receivers: receivers, steps: steps) {
                    newCalls.withLock {
                        $0 += 1
                        return $0 == cancelledAt
                    }
                }
                #expect(oldCalls.withLock { $0 } == newCalls.withLock { $0 })
                #expect((a == nil) == (b == nil))
                if let a, let b { #expect(bits(a) == bits(b)) }
            }
            var oldDone: [Int] = []
            var newDone: [Int] = []
            _ = old.simulate(
                s, source: [0.7, 0.5, 0.8], receivers: receivers, steps: steps, stop: { false },
                abandon: { done, _ in
                    oldDone.append(done)
                    return false
                })
            _ = shared.simulate(
                s, source: [0.7, 0.5, 0.8], receivers: receivers, steps: steps, stop: { false },
                abandon: { done, _ in
                    newDone.append(done)
                    return false
                })
            #expect(oldDone == newDone)
            #expect(newDone == stride(from: 128, to: steps, by: 128).map { $0 })
        }
        var abandonedAt: [Int] = []
        let abandoned = shared.simulate(
            s, source: [0.7, 0.5, 0.8], receivers: receivers, steps: 257, stop: { false },
            abandon: { done, _ in
                abandonedAt.append(done)
                return true
            })
        #expect(abandoned == nil && abandonedAt == [128])
    }

    @Test("Actual shared GPU abandonment restarts a complete fresh CPU response; short runs stay GPU")
    func restart() throws {
        let c = try context()
        let original = solver()
        #expect(original.metalBackend == nil)
        var s = original.usingSharedMetal(context: c)
        s.gpuDelay = 0.3
        let resultValue =
            s.run(source: [0.7, 0.5, 0.8], receivers: receivers, steps: 1024, stop: { false })
        let result = try #require(resultValue)
        #expect(!result.onGPU)
        var cpu = s
        cpu.engine = .cpu
        let expectedValue =
            cpu.run(source: [0.7, 0.5, 0.8], receivers: receivers, steps: 1024, stop: { false })
        let expected = try #require(expectedValue)
        #expect(
            bits(result.signals) == bits(expected.signals) && result.signals.allSatisfy { $0.count == 1024 })
        s.gpuDelay = 0.01
        let shortValue =
            s.run(source: [0.7, 0.5, 0.8], receivers: receivers, steps: 256, stop: { false })
        let short = try #require(shortValue)
        #expect(short.onGPU)
        let directValue =
            SharedMetalSimulation(context: c).simulate(
                s, source: [0.7, 0.5, 0.8], receivers: receivers, steps: 256, stop: { false })
        let direct = try #require(directValue)
        #expect(bits(short.signals) == bits(direct))
    }
    @Test("Concurrent calls share only pipelines and preserve independent complete response histories")
    func concurrent() async throws {
        let c = try context()
        let old = try #require(MetalWaveSolver.shared)
        var controls: [[[UInt64]]] = []
        for run in 0..<4 {
            let s = solver(run % 3)
            let value = old.simulate(
                s, source: [0.7 + 0.1 * Double(run), 0.5, 0.8], receivers: receivers, steps: 257,
                stop: { false })
            controls.append(bits(try #require(value)))
        }
        let actual = try await withThrowingTaskGroup(of: (Int, [[UInt64]]).self) { group in
            for run in 0..<4 {
                group.addTask {
                    let s = solver(run % 3)
                    let value = SharedMetalSimulation(context: c).simulate(
                        s, source: [0.7 + 0.1 * Double(run), 0.5, 0.8], receivers: receivers, steps: 257,
                        stop: { false })
                    return (run, bits(try #require(value)))
                }
            }
            var results: [(Int, [[UInt64]])] = []
            for try await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
        #expect(actual == controls && actual.count == 4)
    }

    @Test("Inactive zeros and nearest-cell source padding retain complete original GPU responses")
    func sourcePadding() throws {
        let c = try context()
        let old = try #require(MetalWaveSolver.shared)
        let shared = SharedMetalSimulation(context: c)
        let s = solver()
        for source: SIMD3<Double> in [[1.99, 1.31, 0.8], [2.9, 1.9, 0.8]] {
            let layout = s.gridLayout(source: source, receivers: receivers)
            #expect(
                zip(layout.sourceCells, layout.sourceWeights).contains {
                    layout.inside[$0.0] == 0 || $0.1 == 0
                })
            let aValue = old.simulate(s, source: source, receivers: receivers, steps: 257, stop: { false })
            let bValue = shared.simulate(s, source: source, receivers: receivers, steps: 257, stop: { false })
            let a = try #require(aValue)
            let b = try #require(bValue)
            #expect(bits(a) == bits(b))
        }
    }

}
