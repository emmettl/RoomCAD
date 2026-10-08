import BenchmarkSupport
import Foundation
import Metal

/// Temporary benchmark bindings; actual numerical CPU blocks and GPU kernels are generated from current source.
final class GPUBridge {
    let p, ux, uy, uz: MTLBuffer
    private let queue: MTLCommandQueue, velocity, pressure: MTLComputePipelineState, inside, faces: MTLBuffer
    private var grid: SourceMetal.Grid
    init(
        nx: Int, ny: Int, nz: Int, c: Double, dt: Double, dx: Double, dy: Double, p: [Float], u: [Float],
        v: [Float], w: [Float],
        beta: Float
    ) throws {
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
        uy = try buffer(v)
        uz = try buffer(w)
        inside = try buffer(Array(repeating: UInt8(1), count: p.count))
        var coefficients = [Float](repeating: 0, count: 6 * p.count)
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let at = i + nx * (j + ny * k)
                    for (face, neighbor) in [i > 0, i < nx - 1, j > 0, j < ny - 1, k > 0, k < nz - 1]
                        .enumerated()
                    {
                        coefficients[face * p.count + at] = neighbor ? -1 : (face == 1 ? beta : 0)
                    }
                }
            }
        }
        faces = try buffer(coefficients)
        grid = SourceMetal.Grid(
            nx: UInt32(nx), ny: UInt32(ny), nz: UInt32(nz), kx: Float(dt / dx), ky: Float(dt / dy),
            kz: Float(dt / (0.125 / Double(nz))),
            bx: Float(c * c * dt / dx), by: Float(c * c * dt / dy),
            bz: Float(c * c * dt / (0.125 / Double(nz))))
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
                MTLSize(width: Int(grid.nx), height: Int(grid.ny), depth: Int(grid.nz)),
                threadsPerThreadgroup: MTLSize(width: min(64, Int(grid.nx)), height: 1, depth: 1))
            encoder.setBuffer(faces, offset: 0, index: 5)
            encoder.setBytes(&grid, length: MemoryLayout<SourceMetal.Grid>.stride, index: 6)
            encoder.setComputePipelineState(pressure)
            encoder.dispatchThreads(
                MTLSize(width: Int(grid.nx), height: Int(grid.ny), depth: Int(grid.nz)),
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
    func fields() -> (p: [Float], u: [Float], v: [Float], w: [Float]) {
        (
            Array(
                UnsafeBufferPointer(
                    start: p.contents().bindMemory(to: Float.self, capacity: p.length / 4),
                    count: p.length / 4)),
            Array(
                UnsafeBufferPointer(
                    start: ux.contents().bindMemory(to: Float.self, capacity: ux.length / 4),
                    count: ux.length / 4)),
            Array(
                UnsafeBufferPointer(
                    start: uy.contents().bindMemory(to: Float.self, capacity: uy.length / 4),
                    count: uy.length / 4)),
            Array(
                UnsafeBufferPointer(
                    start: uz.contents().bindMemory(to: Float.self, capacity: uz.length / 4),
                    count: uz.length / 4))
        )
    }
}

@main struct Rigid3DAdapter {
    static func main() throws {
        let args = CommandLine.arguments
        guard let at = args.firstIndex(of: "--backend"), at + 1 < args.count,
            ["cpu", "metal"].contains(args[at + 1])
        else { throw BenchmarkFailure.invalidCase }
        let backend = args[at + 1]
        try RigidModeCommand.run(model: "RoomCAD.\(backend).rigid-3D", supported: true) { c, r in
            let spacing = zip(c.lengths, r.dimensions).map { $0 / Double($1) }
            let dt = c.duration / Double(r.steps)
            let initial = RigidModeOracle.initial(c, r, spacing: spacing, dt: dt)
            let count = r.nx * r.ny * r.nz
            var p = initial.p.map { Float($0 / c.density) }
            var u = [Float](repeating: 0, count: count)
            var v = u
            var w = u
            for k in 0..<r.nz {
                for j in 0..<r.ny {
                    for i in 0..<r.nx {
                        let at = i + r.nx * (j + r.ny * k)
                        if i < r.nx - 1 { u[at] = Float(initial.u[i + 1 + (r.nx + 1) * (j + r.ny * k)]) }
                        if j < r.ny - 1 { v[at] = Float(initial.v[i + r.nx * (j + 1 + (r.ny + 1) * k)]) }
                        if k < r.nz - 1 { w[at] = Float(initial.w[i + r.nx * (j + r.ny * (k + 1))]) }
                    }
                }
            }
            let cpu =
                backend == "cpu"
                ? SourceCPU(
                    nx: r.nx, ny: r.ny, nz: r.nz, c: c.speed, dt: dt,
                    dx: spacing[0], dy: spacing[1], p: p, u: u, v: v, beta: 0) : nil
            cpu?.uz = w
            let gpu =
                backend == "metal"
                ? try GPUBridge(
                    nx: r.nx, ny: r.ny, nz: r.nz, c: c.speed,
                    dt: dt, dx: spacing[0], dy: spacing[1], p: p, u: u, v: v, w: w, beta: 0) : nil
            var done = 0
            var frames: [RigidModeFrame] = []
            for step in r.captures {
                if let cpu {
                    cpu.advance(step - done)
                    (p, u, v, w) = (cpu.p, cpu.ux, cpu.uy, cpu.uz)
                }
                if let gpu {
                    try gpu.advance(step - done)
                    (p, u, v, w) = gpu.fields()
                }
                done = step
                var vx = [Double](repeating: 0, count: (r.nx + 1) * r.ny * r.nz)
                var vy = [Double](repeating: 0, count: r.nx * (r.ny + 1) * r.nz)
                var vz = [Double](repeating: 0, count: r.nx * r.ny * (r.nz + 1))
                for k in 0..<r.nz {
                    for j in 0..<r.ny {
                        for i in 0..<r.nx {
                            let at = i + r.nx * (j + r.ny * k)
                            if i < r.nx - 1 { vx[i + 1 + (r.nx + 1) * (j + r.ny * k)] = Double(u[at]) }
                            if j < r.ny - 1 { vy[i + r.nx * (j + 1 + (r.ny + 1) * k)] = Double(v[at]) }
                            if k < r.nz - 1 { vz[i + r.nx * (j + r.ny * (k + 1))] = Double(w[at]) }
                        }
                    }
                }
                frames.append(
                    RigidModeFrame(step: step, p: p.map { Double($0) * c.density }, u: vx, v: vy, w: vz))
            }
            return RigidModeHistory(spacing: spacing, dt: dt, frames: frames)
        }
    }
}
