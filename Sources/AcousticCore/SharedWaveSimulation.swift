import Foundation
import LinearAcoustics
import simd

/// App-owned conversion of the actual room layout, with no new geometry or pulse policy.
struct SharedWavePreparation {
    let grid: PreparedWaveGrid
    let source: PreparedPressureSource
    let observation: PreparedWaveObservation

    init(
        solver: WaveSolver, layout: WaveSolver.GridLayout,
        receivers: [(position: SIMD3<Double>, microphone: Microphone)]
    ) throws {
        let grid = try PreparedWaveGrid(
            dimensions: solver.cells, spacing: solver.spacing,
            soundSpeed: solver.atmosphere.soundSpeed, density: 1, timeStep: solver.timeStep,
            activeCells: layout.inside, boundaryTerms: layout.faces)
        self.grid = grid
        guard layout.count == grid.cellCount,
            layout.sourceCells.count == 8,
            layout.sourceCells.count == layout.sourceWeights.count,
            layout.sourceCells.allSatisfy({ $0 >= 0 && $0 < grid.cellCount }),
            layout.receiverCells.count == 8 * receivers.count,
            layout.receiverWeights.count == 8 * receivers.count,
            layout.velocityCells.count == receivers.count,
            layout.axes.count == 3 * receivers.count
        else { throw AcousticError.invalid("Invalid shared wave layout shape.") }
        var cells: [Int] = []
        var coefficients: [Float] = []
        var seen = Set<Int>()
        // Inactive zero slots and repeated zero fallback padding are not sparse writes.
        // Retain unique active zero slots and every nonzero write in their original order.
        for (cell, weight) in zip(layout.sourceCells, layout.sourceWeights) {
            if layout.inside[cell] != 1 || seen.contains(cell) {
                guard weight == 0 else {
                    throw AcousticError.invalid("Invalid shared wave source padding.")
                }
                continue
            }
            seen.insert(cell)
            cells.append(cell)
            coefficients.append(weight)
        }
        source = try PreparedPressureSource(grid: grid, cellIndices: cells, coefficients: coefficients)
        observation = try PreparedWaveObservation(
            grid: grid,
            receivers: receivers.indices.map { r in
                let microphone = receivers[r].microphone
                return WaveReceiverStencil(
                    pressureCells: Array(layout.receiverCells[(8 * r)..<(8 * r + 8)]),
                    pressureWeights: Array(layout.receiverWeights[(8 * r)..<(8 * r + 8)]),
                    velocityCell: microphone.isOmni ? nil : layout.velocityCells[r],
                    velocityAxis: microphone.isOmni ? nil : microphone.axis)
            })
    }

    var zeroFields: WaveInitialFields {
        let zero = [Float](repeating: 0, count: grid.cellCount)
        return WaveInitialFields(
            pressureOverDensity: zero, velocityX: zero, velocityY: zero, velocityZ: zero)
    }
}

/// A run owns its stepper and one-frame lookahead. Cancellation discards all partial output.
struct SharedMaskedCPUSimulation: MaskedCPUSimulation {
    func simulate(
        _ solver: WaveSolver, source: SIMD3<Double>,
        receivers: [(position: SIMD3<Double>, microphone: Microphone)], steps: Int,
        stop: @Sendable () -> Bool
    ) -> [[Double]]? {
        guard steps >= 0 else { return nil }
        // The original empty simulation performs no cancellation check or receiver work.
        guard steps > 0 else { return Array(repeating: [], count: receivers.count) }
        do {
            let layout = solver.gridLayout(source: source, receivers: receivers)
            let prepared = try SharedWavePreparation(solver: solver, layout: layout, receivers: receivers)
            // Retain the original masked loop's caller-owned small-grid/slab policy.
            let execution: CPUWaveExecution =
                layout.count < 4_096 ? .serial : .parallel(slabs: min(solver.cells.z, 16))
            let stepper = try CPUWaveStepper(
                grid: prepared.grid, initialFields: prepared.zeroFields, execution: execution)
            var aligner = WaveObservationAligner()
            var output = Array(repeating: [Double](), count: receivers.count)
            for r in output.indices { output[r].reserveCapacity(steps) }
            let c = solver.atmosphere.soundSpeed
            var outputIndex = 0
            func append(_ frames: [AlignedWaveObservationFrame]) throws {
                for frame in frames {
                    guard frame.pressureStepIndex == outputIndex + 1,
                        frame.timeStep == solver.timeStep
                    else { throw AcousticError.invalid("Invalid shared wave output clock.") }
                    outputIndex += 1
                    for r in receivers.indices {
                        let microphone = receivers[r].microphone
                        let pressure = frame.pressureOverDensity[r]
                        if microphone.isOmni {
                            output[r].append(pressure)
                        } else {
                            let a = microphone.pattern.omniShare
                            // Preparation guarantees the directional velocity's presence.
                            output[r].append(a * pressure - (1 - a) * c * frame.projectedVelocity[r]!)
                        }
                    }
                }
            }
            var start = 0
            while start < steps {
                if stop() { return nil }
                let end = min(start + 64, steps)
                let amplitudes = (start..<end).map {
                    Float(solver.pulse((Double($0) + 0.5) * solver.timeStep))
                }
                let frames = try stepper.advance(
                    source: prepared.source, amplitudes: amplitudes, observing: prepared.observation)
                try append(try aligner.append(frames))
                start = end
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
    /// Explicit app comparison path. The optimized unmasked CPU box path stays in use.
    func usingSharedMaskedCPU() -> Self {
        var result = self
        result.maskedCPUBackend = SharedMaskedCPUSimulation()
        return result
    }
}
