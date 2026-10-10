import Foundation
import LinearAcoustics
import LinearAcousticsMetal
import Metal

/// Immutable compiled pipelines can be reused; every call owns its stepper and output.
struct SharedMetalSimulation: MetalSimulation {
    let context: MetalWaveContext

    /// Application-owned hardware selection and immutable pipeline reuse.
    static let shared: Self? = {
        guard let device = MTLCreateSystemDefaultDevice(),
            let context = try? MetalWaveContext(device: device)
        else { return nil }
        return Self(context: context)
    }()

    func simulate(
        _ solver: WaveSolver, source: SIMD3<Double>,
        receivers: [(position: SIMD3<Double>, microphone: Microphone)], steps: Int,
        stop: @Sendable () -> Bool,
        abandon: (_ done: Int, _ elapsed: TimeInterval) -> Bool = { _, _ in false }
    ) -> [[Double]]? {
        guard steps >= 0 else { return nil }
        guard steps > 0 else { return Array(repeating: [], count: receivers.count) }
        let started = Date()
        do {
            let layout = solver.gridLayout(source: source, receivers: receivers)
            let prepared = try SharedWavePreparation(solver: solver, layout: layout, receivers: receivers)
            let stepper = try MetalWaveStepper(
                context: context, grid: prepared.grid, initialFields: prepared.zeroFields)
            let sourcePlan = try stepper.prepareSource(prepared.source)
            let observation = try stepper.prepareObservation(prepared.observation)
            var aligner = WaveObservationAligner()
            var output = Array(repeating: [Double](), count: receivers.count)
            for r in output.indices { output[r].reserveCapacity(steps) }
            let c = solver.atmosphere.soundSpeed
            var outputIndex = 0
            func append(_ frames: [AlignedWaveObservationFrame]) throws {
                for frame in frames {
                    guard frame.pressureStepIndex == outputIndex + 1,
                        frame.timeStep == solver.timeStep
                    else { throw AcousticError.invalid("Invalid shared Metal output clock.") }
                    outputIndex += 1
                    for r in receivers.indices {
                        let microphone = receivers[r].microphone
                        let pressure = frame.pressureOverDensity[r]
                        if microphone.isOmni {
                            output[r].append(pressure)
                        } else {
                            let a = microphone.pattern.omniShare
                            output[r].append(a * pressure - (1 - a) * c * frame.projectedVelocity[r]!)
                        }
                    }
                }
            }
            var start = 0
            while start < steps {
                if stop() { return nil }
                let end = min(start + WaveSolver.gpuStepsPerBuffer, steps)
                let amplitudes = (start..<end).map {
                    Float(solver.pulse((Double($0) + 0.5) * solver.timeStep))
                }
                let frames = try stepper.advance(
                    source: sourcePlan, amplitudes: amplitudes, observing: observation)
                try append(try aligner.append(frames))
                if solver.gpuDelay > 0 { Thread.sleep(forTimeInterval: solver.gpuDelay) }
                start = end
                if start < steps, abandon(start, Date().timeIntervalSince(started)) { return nil }
            }
            try append(try aligner.finishUsingFinalHalfStep())
            guard outputIndex == steps else { return nil }
            return output
        } catch {
            return nil
        }
    }
}

extension WaveSolver {
    /// Explicit device-context selection for conformance and application comparisons.
    func usingSharedMetal(context: MetalWaveContext) -> Self {
        var result = self
        result.metalBackend = SharedMetalSimulation(context: context)
        return result
    }
}
