import Foundation
import Testing

@testable import AcousticCore

@Suite("Selected Metal availability and fresh CPU fallback")
struct MetalSelectionTests {
    private let source: SIMD3<Double> = [0.7, 0.5, 0.8]
    private let receivers: [(position: SIMD3<Double>, microphone: Microphone)] = [
        ([1.2, 0.8, 0.7], .omni),
        ([1.3, 0.6, 0.8], Microphone(pattern: .cardioid, azimuth: 30)),
    ]

    private func solver() -> WaveSolver {
        var room = ShoeboxRoom(size: [3, 2, 1.5], material: .uniform(0.2, name: "Wall"))
        room.plan = .rectangle([3, 2], material: .uniform(0.2, name: "Wall"))
        return WaveSolver(room: room, sampleRate: 48_000, topFrequency: 100, atmosphere: .standard)
    }

    private struct FailingBackend: MetalSimulation {
        func simulate(
            _ solver: WaveSolver, source: SIMD3<Double>,
            receivers: [(position: SIMD3<Double>, microphone: Microphone)], steps: Int,
            stop: @Sendable () -> Bool, abandon: (Int, TimeInterval) -> Bool
        ) -> [[Double]]? { nil }
    }

    private struct ForbiddenBackend: MetalSimulation {
        func simulate(
            _ solver: WaveSolver, source: SIMD3<Double>,
            receivers: [(position: SIMD3<Double>, microphone: Microphone)], steps: Int,
            stop: @Sendable () -> Bool, abandon: (Int, TimeInterval) -> Bool
        ) -> [[Double]]? { preconditionFailure("CPU-only route invoked a GPU backend") }
    }

    @Test("Unavailable selected context uses complete CPU output for automatic and forced GPU routes")
    func unavailable() throws {
        for engine in [WaveSolver.Engine.automatic, .gpu] {
            var s = solver()
            s.engine = engine
            s.metalBackend = nil
            #expect(!s.usesGPU)
            for steps in [0, 1, 129] {
                let rawResult = s.run(source: source, receivers: receivers, steps: steps, stop: { false })
                let result = try #require(rawResult)
                let rawExpected = s.simulate(
                    source: source, receivers: receivers, steps: steps, stop: { false })
                let expected = try #require(rawExpected)
                #expect(
                    !result.onGPU
                        && result.signals.map { $0.map(\.bitPattern) }
                            == expected.map { $0.map(\.bitPattern) }
                )
            }
        }
    }

    @Test("Selected backend failure returns a complete fresh CPU response and preserves cancellation")
    func failure() throws {
        var s = solver()
        s.engine = .gpu
        s.metalBackend = FailingBackend()
        #expect(s.usesGPU)
        let rawResult = s.run(source: source, receivers: receivers, steps: 257, stop: { false })
        let result = try #require(rawResult)
        let rawExpected = s.simulate(source: source, receivers: receivers, steps: 257, stop: { false })
        let expected = try #require(rawExpected)
        #expect(
            !result.onGPU
                && result.signals.map { $0.map(\.bitPattern) } == expected.map { $0.map(\.bitPattern) })
        let cancelled = s.run(source: source, receivers: receivers, steps: 257, stop: { true })
        #expect(cancelled == nil)
    }

    @Test("Explicit CPU routing does not query or invoke a selected GPU implementation")
    func cpuOnly() throws {
        var s = solver()
        s.engine = .cpu
        s.metalBackend = ForbiddenBackend()
        #expect(!s.usesGPU)
        let rawResult = s.run(source: source, receivers: receivers, steps: 129, stop: { false })
        let result = try #require(rawResult)
        #expect(!result.onGPU)
    }

    @Test("Planner uses CPU budget and crossover when the selected context is unavailable")
    func planning() throws {
        let prototype = solver()
        let settings = RoomResponseSettings(
            room: prototype.room, source: RoomPoint(name: "S", position: source),
            receivers: [RoomPoint(name: "R", position: receivers[0].position)],
            duration: 1, lowFrequencyModel: true)
        func factory(_ cpu: Bool) -> (Double) -> WaveSolver {
            { crossover in
                var s = WaveSolver(
                    room: settings.room, sampleRate: settings.sampleRate,
                    topFrequency: crossover * 2.squareRoot(), atmosphere: settings.atmosphere)
                s.metalBackend = cpu ? ForbiddenBackend() : nil
                if cpu { s.engine = .cpu }
                return s
            }
        }
        let unavailable = try #require(
            WavePlan(settings: settings, schroeder: 200, fftLength: 1 << 16, solverFactory: factory(false)))
        let cpu = try #require(
            WavePlan(settings: settings, schroeder: 200, fftLength: 1 << 16, solverFactory: factory(true)))
        #expect(
            !unavailable.solver.usesGPU && unavailable.crossover == cpu.crossover
                && unavailable.solver.cells == cpu.solver.cells)
        #expect(unavailable.crossover <= 250)
        let work =
            unavailable.solver.cost(duration: Double(1 << 16) / Double(settings.sampleRate))
            * Double(unavailable.solver.bandGroups.count)
        #expect(work <= WavePlan.cpuBudget / 2)
    }
}
