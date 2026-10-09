// Benchmark observation adapters only; numerical state/evolution belongs to ContinuumKit.
import Foundation
import LinearAcoustics
import LinearAcousticsMetal
import Metal
import simd

@testable import AcousticCore

enum SharedObserverFailure: Error { case deviceUnavailable, allocation, clockMismatch }
final class SharedWaveCPU {
    let p, ux, uy, uz: UnsafeMutablePointer<Float>
    private let count: Int
    private let stepper: CPUWaveStepper
    private var completed = 0
    init(
        nx: Int, ny: Int, nz: Int, c: Double, density: Double, dt: Double, spacing: SIMD3<Double>,
        layout: WaveSolver.GridLayout, pressure: [Float], u: [Float], v: [Float], w: [Float]
    ) throws {
        let count = nx * ny * nz
        self.count = count
        let grid = try PreparedWaveGrid(
            dimensions: [nx, ny, nz], spacing: spacing, soundSpeed: c, density: density,
            timeStep: dt, activeCells: layout.inside, boundaryTerms: layout.faces)
        stepper = try CPUWaveStepper(
            grid: grid,
            initialFields: WaveInitialFields(
                pressureOverDensity: pressure,
                velocityX: u, velocityY: v, velocityZ: w))
        func pointer() -> UnsafeMutablePointer<Float> {
            let result = UnsafeMutablePointer<Float>.allocate(capacity: count)
            result.initialize(repeating: 0, count: count)
            return result
        }
        p = pointer()
        ux = pointer()
        uy = pointer()
        uz = pointer()
        try refresh()
    }
    deinit {
        for field in [p, ux, uy, uz] {
            field.deinitialize(count: count)
            field.deallocate()
        }
    }
    private func refresh() throws {
        let h = try stepper.snapshot()
        guard h.pressureStepIndex == completed else { throw SharedObserverFailure.clockMismatch }
        for (buffer, values) in zip(
            [p, ux, uy, uz], [h.pressureOverDensity, h.velocityX, h.velocityY, h.velocityZ])
        {
            values.withUnsafeBufferPointer { buffer.update(from: $0.baseAddress!, count: count) }
        }
    }
    func advance(_ steps: Int) throws {
        try stepper.advance(steps: steps)
        completed += steps
        try refresh()
    }
    func fields() -> (p: [Float], u: [Float], v: [Float], w: [Float]) {
        func values(_ pointer: UnsafeMutablePointer<Float>) -> [Float] {
            Array(UnsafeBufferPointer(start: pointer, count: count))
        }
        return (values(p), values(ux), values(uy), values(uz))
    }
}
final class SharedWaveGPU {
    // These are observation mirrors for legacy wall-trace code, not evolution buffers.
    let p, ux, uy, uz: any MTLBuffer
    private let count: Int
    private let stepper: MetalWaveStepper
    private var completed = 0
    init(
        nx: Int, ny: Int, nz: Int, c: Double, density: Double, dt: Double, dx: Double, dy: Double,
        dz: Double? = nil,
        p: [Float], u: [Float], v: [Float], w: [Float], layout: WaveSolver.GridLayout
    ) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw SharedObserverFailure.deviceUnavailable
        }
        let count = nx * ny * nz
        self.count = count
        let grid = try PreparedWaveGrid(
            dimensions: [nx, ny, nz], spacing: [dx, dy, dz ?? 0.125 / Double(nz)], soundSpeed: c,
            density: density, timeStep: dt, activeCells: layout.inside, boundaryTerms: layout.faces)
        stepper = try MetalWaveStepper(
            device: device, grid: grid,
            initialFields: WaveInitialFields(pressureOverDensity: p, velocityX: u, velocityY: v, velocityZ: w)
        )
        func buffer() throws -> any MTLBuffer {
            guard
                let result = device.makeBuffer(
                    length: count * MemoryLayout<Float>.stride, options: .storageModeShared)
            else { throw SharedObserverFailure.allocation }
            return result
        }
        self.p = try buffer()
        ux = try buffer()
        uy = try buffer()
        uz = try buffer()
        try refresh()
    }
    private func refresh() throws {
        let h = try stepper.snapshot()
        guard h.pressureStepIndex == completed else { throw SharedObserverFailure.clockMismatch }
        for (buffer, values) in zip(
            [p, ux, uy, uz], [h.pressureOverDensity, h.velocityX, h.velocityY, h.velocityZ])
        {
            values.withUnsafeBytes {
                buffer.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count)
            }
        }
    }
    func advance(_ steps: Int) throws {
        try stepper.advance(steps: steps)
        completed += steps
        try refresh()
    }
    func fields() -> (p: [Float], u: [Float], v: [Float], w: [Float]) {
        func values(_ buffer: any MTLBuffer) -> [Float] {
            Array(
                UnsafeBufferPointer(
                    start: buffer.contents().assumingMemoryBound(to: Float.self), count: count))
        }
        return (values(p), values(ux), values(uy), values(uz))
    }
}
