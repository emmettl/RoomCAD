import BenchmarkSupport
import Foundation
import Metal

/// Temporary benchmark bindings; actual numerical CPU blocks and GPU kernels are generated from current source.
final class GPUBridge {
    let p, ux, uy, uz: MTLBuffer
    private let queue: MTLCommandQueue, velocity, pressure: MTLComputePipelineState, inside, faces: MTLBuffer
    private var grid: SourceMetal.Grid
    init(nx: Int, c: Double, dt: Double, dx: Double, p: [Float], u: [Float]) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw BenchmarkFailure.unsupported("Required Metal device unavailable")
        }
        self.queue = queue
        let library = try device.makeLibrary(source: SourceMetal.source, options: nil)
        guard let vf = library.makeFunction(name: "waveVelocity"),
            let pf = library.makeFunction(name: "wavePressure")
        else {
            throw BenchmarkFailure.failedConformance("Production Metal kernels unavailable")
        }
        velocity = try device.makeComputePipelineState(function: vf)
        pressure = try device.makeComputePipelineState(function: pf)
        func buffer<T>(_ array: [T]) throws -> MTLBuffer {
            guard
                let b = array.withUnsafeBytes({
                    device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
                })
            else {
                throw BenchmarkFailure.failedConformance("Metal allocation failed")
            }
            return b
        }
        self.p = try buffer(p)
        ux = try buffer(u)
        uy = try buffer(Array(repeating: Float(0), count: p.count))
        uz = try buffer(Array(repeating: Float(0), count: p.count))
        inside = try buffer(Array(repeating: UInt8(1), count: p.count))
        var coefficients = [Float](repeating: 0, count: 6 * p.count)
        for k in 0..<4 {
            for j in 0..<4 {
                for i in 0..<nx {
                    let at = i + nx * (j + 4 * k)
                    for (face, neighbor) in [i > 0, i < nx - 1, j > 0, j < 3, k > 0, k < 3].enumerated() {
                        coefficients[face * p.count + at] = neighbor ? -1 : 0
                    }
                }
            }
        }
        faces = try buffer(coefficients)
        grid = SourceMetal.Grid(
            nx: UInt32(nx), ny: 4, nz: 4, kx: Float(dt / dx), ky: Float(dt / (0.125 / 4)),
            kz: Float(dt / (0.125 / 4)),
            bx: Float(c * c * dt / dx), by: Float(c * c * dt / (0.125 / 4)),
            bz: Float(c * c * dt / (0.125 / 4)))
    }
    func advance(_ steps: Int) throws {
        guard steps > 0 else { return }
        guard let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder()
        else {
            throw BenchmarkFailure.failedConformance("Metal command unavailable")
        }
        for _ in 0..<steps {
            for (index, b) in [p, ux, uy, uz, inside].enumerated() {
                encoder.setBuffer(b, offset: 0, index: index)
            }
            encoder.setBytes(&grid, length: MemoryLayout<SourceMetal.Grid>.stride, index: 5)
            encoder.setComputePipelineState(velocity)
            encoder.dispatchThreads(
                MTLSize(width: Int(grid.nx), height: 4, depth: 4),
                threadsPerThreadgroup: MTLSize(width: min(64, Int(grid.nx)), height: 1, depth: 1))
            encoder.setBuffer(faces, offset: 0, index: 5)
            encoder.setBytes(&grid, length: MemoryLayout<SourceMetal.Grid>.stride, index: 6)
            encoder.setComputePipelineState(pressure)
            encoder.dispatchThreads(
                MTLSize(width: Int(grid.nx), height: 4, depth: 4),
                threadsPerThreadgroup: MTLSize(width: min(64, Int(grid.nx)), height: 1, depth: 1))
        }
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        if let error = command.error { throw error }
        guard command.status == .completed else {
            throw BenchmarkFailure.failedConformance("Metal update did not complete")
        }
    }
    func fields() -> (p: [Float], u: [Float]) {
        (
            Array(
                UnsafeBufferPointer(
                    start: p.contents().bindMemory(to: Float.self, capacity: p.length / 4),
                    count: p.length / 4)),
            Array(
                UnsafeBufferPointer(
                    start: ux.contents().bindMemory(to: Float.self, capacity: ux.length / 4),
                    count: ux.length / 4))
        )
    }
}

@main struct AcousticAdapter {
    static func main() throws {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--backend"), index + 1 < args.count,
            ["cpu", "metal"].contains(args[index + 1])
        else {
            throw BenchmarkFailure.failedConformance("Supply --backend cpu or metal")
        }
        let backend = args[index + 1]
        try AcousticCommand.run(model: "RoomCAD.WaveSolver.\(backend).axial-plane") { c, r in
            let dx = c.lengthM / Double(r.cells)
            let dt = c.durationS / Double(r.steps)
            let initial = AcousticOracle.initialFields(c, cells: r.cells, spacingM: dx, timeStepS: dt)
            var p = [Float](repeating: 0, count: r.cells * 16)
            var u = p
            for row in 0..<16 {
                for i in 0..<r.cells { p[row * r.cells + i] = Float(initial.pressurePa[i] / c.densityKgM3) }
                for i in 0..<(r.cells - 1) {
                    u[row * r.cells + i] = Float(initial.velocityMinusHalfMps[i + 1])
                }
            }
            let cpu =
                backend == "cpu"
                ? SourceCPU(nx: r.cells, c: c.soundSpeedMps, dt: dt, dx: dx, p: p, u: u) : nil
            let gpu =
                backend == "metal"
                ? try GPUBridge(nx: r.cells, c: c.soundSpeedMps, dt: dt, dx: dx, p: p, u: u) : nil
            var frames: [AcousticFrame] = []
            var done = 0
            for step in r.captureSteps(for: c) {
                if let cpu {
                    cpu.advance(step - done)
                    p = cpu.p
                    u = cpu.ux
                }
                if let gpu {
                    try gpu.advance(step - done)
                    (p, u) = gpu.fields()
                }
                done = step
                var pressure = [Double](repeating: 0, count: r.cells)
                var velocity = [Double](repeating: 0, count: r.cells + 1)
                for row in 0..<16 {
                    for i in 0..<r.cells { pressure[i] += Double(p[row * r.cells + i]) * c.densityKgM3 / 16 }
                    for i in 1..<r.cells { velocity[i] += Double(u[row * r.cells + i - 1]) / 16 }
                }
                // The CPU's general/interior paths may differ by Float32 roundoff across rows.
                let transverse = (0..<p.count).map {
                    abs(Double(p[$0]) * c.densityKgM3 - pressure[$0 % r.cells]) / c.amplitudePa
                }.max()!
                guard transverse < 1e-4 else {
                    throw BenchmarkFailure.failedConformance(
                        "Transverse plane symmetry failed: \(transverse)")
                }
                frames.append(AcousticFrame(step: step, pressurePa: pressure, normalVelocityMps: velocity))
            }
            return AcousticHistory(spacingM: dx, timeStepS: dt, frames: frames)
        }
    }
}
