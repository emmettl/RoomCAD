import BenchmarkSupport
import Foundation
import Metal

/// Temporary benchmark bindings; actual numerical CPU blocks and GPU kernels are generated from current source.
final class GPUBridge {
    let p, ux, uy, uz: MTLBuffer
    private let queue: MTLCommandQueue, velocity, pressure: MTLComputePipelineState, inside, faces: MTLBuffer
    private var grid: SourceMetal.Grid
    init(
        nx: Int, ny: Int, c: Double, dt: Double, dx: Double, dy: Double, p: [Float], u: [Float], v: [Float],
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
        uz = try buffer(Array(repeating: Float(0), count: p.count))
        inside = try buffer(Array(repeating: UInt8(1), count: p.count))
        var coefficients = [Float](repeating: 0, count: 6 * p.count)
        for k in 0..<4 {
            for j in 0..<ny {
                for i in 0..<nx {
                    let at = i + nx * (j + ny * k)
                    for (face, neighbor) in [i > 0, i < nx - 1, j > 0, j < ny - 1, k > 0, k < 3].enumerated()
                    {
                        coefficients[face * p.count + at] = neighbor ? -1 : (face == 1 ? beta : 0)
                    }
                }
            }
        }
        faces = try buffer(coefficients)
        grid = SourceMetal.Grid(
            nx: UInt32(nx), ny: UInt32(ny), nz: 4, kx: Float(dt / dx), ky: Float(dt / dy),
            kz: Float(dt / (0.125 / 4)),
            bx: Float(c * c * dt / dx), by: Float(c * c * dt / dy),
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
                MTLSize(width: Int(grid.nx), height: Int(grid.ny), depth: 4),
                threadsPerThreadgroup: MTLSize(width: min(64, Int(grid.nx)), height: 1, depth: 1))
            encoder.setBuffer(faces, offset: 0, index: 5)
            encoder.setBytes(&grid, length: MemoryLayout<SourceMetal.Grid>.stride, index: 6)
            encoder.setComputePipelineState(pressure)
            encoder.dispatchThreads(
                MTLSize(width: Int(grid.nx), height: Int(grid.ny), depth: 4),
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
    func fields() -> (p: [Float], u: [Float], v: [Float]) {
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
                    count: uy.length / 4))
        )
    }
}

@main struct BoundaryAdapter {
    static func main() throws {
        let args = CommandLine.arguments
        guard let at = args.firstIndex(of: "--backend"), at + 1 < args.count,
            ["cpu", "metal"].contains(args[at + 1])
        else { throw BenchmarkFailure.invalidCase }
        let backend = args[at + 1]
        try BoundaryCommand.run(model: "RoomCAD.\(backend).boundaries", supportsImpedance: true) { c, r in
            let dx = c.lengthX / Double(r.nx)
            let dy = c.lengthY / Double(r.ny)
            let dt = c.duration / Double(r.steps)
            let nz = 4
            let count = r.nx * r.ny * nz
            let initial = BoundaryOracle.initial(c, r, dx: dx, dy: dy, dt: dt)
            var p = [Float](repeating: 0, count: count)
            var u = p
            var v = p
            for k in 0..<nz {
                for j in 0..<r.ny {
                    for i in 0..<r.nx {
                        let at = i + r.nx * (j + r.ny * k)
                        p[at] = Float(initial.p[j * r.nx + i] / c.density)
                        if i < r.nx - 1 { u[at] = Float(initial.u[j * (r.nx + 1) + i + 1]) }
                        if j < r.ny - 1 { v[at] = Float(initial.v[(j + 1) * r.nx + i]) }
                    }
                }
            }
            let beta = c.impedance.map { Float(c.speed * dt / (2 * $0 * dx)) } ?? 0
            let cpu =
                backend == "cpu"
                ? SourceCPU(
                    nx: r.nx, ny: r.ny, nz: nz, c: c.speed, dt: dt, dx: dx, dy: dy, p: p, u: u, v: v,
                    beta: beta) : nil
            let gpu =
                backend == "metal"
                ? try GPUBridge(
                    nx: r.nx, ny: r.ny, c: c.speed, dt: dt, dx: dx, dy: dy, p: p, u: u, v: v, beta: beta)
                : nil
            var frames: [BoundaryFrame] = []
            var done = 0
            var loss = 0.0
            var flux = [Double](repeating: 0, count: r.ny)
            func advance(_ n: Int) throws {
                if let cpu {
                    cpu.advance(n)
                    p = cpu.p
                    u = cpu.ux
                    v = cpu.uy
                }
                if let gpu {
                    try gpu.advance(n)
                    (p, u, v) = gpu.fields()
                }
            }
            for step in r.captures(c) {
                if let xi = c.impedance {
                    while done < step {
                        let old = (0..<r.ny * nz).map { Double(p[$0 * r.nx + r.nx - 1]) }
                        try advance(1)
                        done += 1
                        flux = Array(repeating: 0, count: r.ny)
                        for row in 0..<r.ny * nz {
                            let average = (old[row] + Double(p[row * r.nx + r.nx - 1])) / 2
                            loss += c.density * dt * dy / Double(nz) * average * average / (c.speed * xi)
                            flux[row % r.ny] += average / (c.speed * xi * Double(nz))
                        }
                    }
                } else {
                    try advance(step - done)
                    done = step
                }
                var pressure = [Double](repeating: 0, count: r.nx * r.ny)
                var vx = [Double](repeating: 0, count: (r.nx + 1) * r.ny)
                var vy = [Double](repeating: 0, count: r.nx * (r.ny + 1))
                for k in 0..<nz {
                    for j in 0..<r.ny {
                        for i in 0..<r.nx {
                            let at = i + r.nx * (j + r.ny * k)
                            pressure[j * r.nx + i] += Double(p[at]) * c.density / Double(nz)
                            if i < r.nx - 1 { vx[j * (r.nx + 1) + i + 1] += Double(u[at]) / Double(nz) }
                            if j < r.ny - 1 { vy[(j + 1) * r.nx + i] += Double(v[at]) / Double(nz) }
                        }
                    }
                }
                for j in 0..<r.ny { vx[j * (r.nx + 1) + r.nx] = flux[j] }
                let variation = p.indices.map {
                    abs(Double(p[$0]) * c.density - pressure[$0 % (r.nx * r.ny)])
                }.max()!
                guard variation < 1e-4 else {
                    throw BenchmarkFailure.failedConformance("Extruded-plane variation \(variation)")
                }
                frames.append(BoundaryFrame(step: step, p: pressure, u: vx, v: vy, dissipation: loss))
            }
            return BoundaryHistory(dx: dx, dy: dy, dt: dt, frames: frames)
        }
    }
}
