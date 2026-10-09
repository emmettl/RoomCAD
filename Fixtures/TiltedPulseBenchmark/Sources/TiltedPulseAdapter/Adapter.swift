import BenchmarkSupport
import Foundation
import Metal

@testable import AcousticCore

/// Temporary benchmark bindings; actual numerical CPU blocks and GPU kernels are generated from current source.
final class TiltedPulseGPU {
    let p, ux, uy, uz: MTLBuffer
    private let queue: MTLCommandQueue, velocity, pressure: MTLComputePipelineState, inside, faces: MTLBuffer
    private var grid: MetalWaveSolver.Grid
    init(
        nx: Int, ny: Int, nz: Int, c: Double, dt: Double, dx: Double, dy: Double, dz: Double, p: [Float],
        u: [Float],
        v: [Float], w: [Float],
        layout: WaveSolver.GridLayout
    ) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw BenchmarkFailure.unsupported("Required Metal device unavailable")
        }
        self.queue = queue
        let library = try device.makeLibrary(source: MetalWaveSolver.source, options: nil)
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
        inside = try buffer(layout.inside)
        faces = try buffer(layout.faces)
        grid = MetalWaveSolver.Grid(
            nx: UInt32(nx), ny: UInt32(ny), nz: UInt32(nz), kx: Float(dt / dx), ky: Float(dt / dy),
            kz: Float(dt / dz),
            bx: Float(c * c * dt / dx), by: Float(c * c * dt / dy),
            bz: Float(c * c * dt / dz))
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
            encoder.setBytes(&grid, length: MemoryLayout<MetalWaveSolver.Grid>.stride, index: 5)
            encoder.setComputePipelineState(velocity)
            encoder.dispatchThreads(
                MTLSize(width: Int(grid.nx), height: Int(grid.ny), depth: Int(grid.nz)),
                threadsPerThreadgroup: MTLSize(width: min(64, Int(grid.nx)), height: 1, depth: 1))
            encoder.setBuffer(faces, offset: 0, index: 5)
            encoder.setBytes(&grid, length: MemoryLayout<MetalWaveSolver.Grid>.stride, index: 6)
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

@main struct TiltedPulseAdapter {
    static func main() throws {
        let args = CommandLine.arguments
        guard let at = args.firstIndex(of: "--backend"), at + 1 < args.count,
            ["cpu", "metal"].contains(args[at + 1])
        else { throw BenchmarkFailure.invalidCase }
        let backend = args[at + 1]
        try TiltedPulseCommand.run(model: "RoomCAD.\(backend).tilted-pulse", supported: true) {
            c, r in
            let grid = try TiltedPulseGrid(c, r)
            let spacing = grid.spacing
            let dt = c.duration / Double(r.steps)
            let initial = try TiltedPulseOracle.initial(c, r, dt: dt)
            let material = SurfaceMaterial.rigid
            let alpha = 8 / c.impedance * (1 + 1 / (1 + c.impedance) - 2 / c.impedance * log(1 + c.impedance))
            let absorber = SurfaceMaterial.uniform(
                alpha, name: "Independent xi=3 tilted pulse",
                reference: "Independently authored statistical absorption integral")
            var room = ShoeboxRoom(size: SIMD3<Double>(c.lengths), material: material)
            room.plan = FloorPlan(
                corners: [
                    [0, 0], [c.intercept, 0], [c.intercept - c.lengths[1] / 2, c.lengths[1]],
                    [0, c.lengths[1]],
                ], walls: [material, absorber, material, material])
            let atmosphere = Atmosphere(
                temperatureCelsius: pow(c.speed / 331.3, 2) * 273.15 - 273.15, relativeHumidity: 0,
                pressureKilopascals: 101.325)
            let solver = WaveSolver(
                room: room, sampleRate: 768000,
                topFrequency: atmosphere.soundSpeed * Double(r.nx) / (10 * c.lengths[0]) * (1 - 1e-9),
                atmosphere: atmosphere)
            guard solver.cells == SIMD3<Int>(r.dimensions) else { throw BenchmarkFailure.invalidSamples }
            let actualLayout = solver.gridLayout(source: [c.centre, 0.25, c.lengths[2] / 2], receivers: [])
            guard actualLayout.inside == grid.inside else {
                throw BenchmarkFailure.failedConformance(
                    "Actual plan mask disagrees with independent half-plane occupancy")
            }
            var layout = actualLayout
            for i in layout.faces.indices where layout.faces[i] >= 0 {
                layout.faces[i] = Float(Double(layout.faces[i]) * dt / solver.timeStep)
            }
            let wallCells = grid.wallCells
            let wallRates = try grid.rates(faces: layout.faces, dt: dt)
            let volume = spacing.reduce(1, *)
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
                ? SourceTiltedPulseCPU(
                    nx: r.nx, ny: r.ny, nz: r.nz, c: c.speed, dt: dt, spacing: SIMD3<Double>(spacing),
                    layout: layout, pressure: p, u: u, v: v, w: w) : nil
            let gpu =
                backend == "metal"
                ? try TiltedPulseGPU(
                    nx: r.nx, ny: r.ny, nz: r.nz, c: c.speed, dt: dt, dx: spacing[0], dy: spacing[1],
                    dz: spacing[2], p: p,
                    u: u, v: v, w: w, layout: layout) : nil
            var frames: [RigidModeFrame] = []
            var wallTrace: [[Double]] = []
            var dissipation: [Double] = []
            var patchDissipation: [Double] = []
            var patchWork = 0.0
            var work = 0.0
            for step in 0...r.steps {
                if step > 0 {
                    cpu?.advance(1)
                    try gpu?.advance(1)
                }
                let pointer: UnsafeMutablePointer<Float>
                if let cpu {
                    pointer = cpu.p
                } else if let gpu {
                    pointer = gpu.p.contents().bindMemory(to: Float.self, capacity: count)
                } else {
                    throw BenchmarkFailure.invalidSamples
                }
                let row = wallCells.map { Double(pointer[$0]) * c.density }
                if let previous = wallTrace.last {
                    for (i, cell) in wallCells.enumerated() {
                        let increment =
                            dt * volume * pow((previous[i] + row[i]) / 2, 2) / (c.density * c.speed * c.speed)
                        work += increment * wallRates.total[cell]
                        patchWork += increment * wallRates.patch[cell]
                    }
                }
                wallTrace.append(row)
                guard r.captures.contains(step) else { continue }
                dissipation.append(work)
                patchDissipation.append(patchWork)
                if let cpu { (p, u, v, w) = cpu.fields() }
                if let gpu { (p, u, v, w) = gpu.fields() }
                var vx = [Double](repeating: 0, count: (r.nx + 1) * r.ny * r.nz)
                var vy = [Double](repeating: 0, count: r.nx * (r.ny + 1) * r.nz)
                var vz = [Double](repeating: 0, count: r.nx * r.ny * (r.nz + 1))
                for k in 0..<r.nz {
                    for j in 0..<r.ny {
                        for i in 0..<r.nx {
                            let at = i + r.nx * (j + r.ny * k)
                            do { vx[i + 1 + (r.nx + 1) * (j + r.ny * k)] = Double(u[at]) }
                            do { vy[i + r.nx * (j + 1 + (r.ny + 1) * k)] = Double(v[at]) }
                            do { vz[i + r.nx * (j + r.ny * (k + 1))] = Double(w[at]) }
                        }
                    }
                }
                frames.append(
                    RigidModeFrame(step: step, p: p.map { Double($0) * c.density }, u: vx, v: vy, w: vz))
            }
            return TiltedPulseHistory(
                fields: RigidModeHistory(spacing: spacing, dt: dt, frames: frames),
                inside: actualLayout.inside, faces: layout.faces, layoutFaces: actualLayout.faces,
                layoutDt: solver.timeStep, materialImpedance: solver.impedance(material: absorber),
                wallCells: wallCells, wallPressures: wallTrace, dissipation: dissipation,
                patchDissipation: patchDissipation)
        }
    }
}
