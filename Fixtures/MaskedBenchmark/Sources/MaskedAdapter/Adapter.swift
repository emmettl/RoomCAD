@testable import AcousticCore
import BenchmarkSupport
import Foundation
import Metal

/// Temporary benchmark bindings; actual numerical CPU blocks and GPU kernels are generated from current source.
final class MaskedGPU {
    let p, ux, uy, uz: MTLBuffer
    private let queue: MTLCommandQueue, velocity, pressure: MTLComputePipelineState, inside, faces: MTLBuffer
    private var grid: MetalWaveSolver.Grid
    init(
        nx: Int, ny: Int, nz: Int, c: Double, dt: Double, dx: Double, dy: Double, p: [Float], u: [Float],
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

@main struct MaskedAdapter {
    static func main() throws {
        let args = CommandLine.arguments
        guard let at = args.firstIndex(of: "--backend"), at + 1 < args.count,
            ["cpu", "metal"].contains(args[at + 1])
        else { throw BenchmarkFailure.invalidCase }
        let backend = args[at + 1]
        try MaskedModeCommand.run(model: "RoomCAD.\(backend).masked", supported: true) { c, r in
            let spacing = zip(c.lengths, r.dimensions).map { $0 / Double($1) }
            let dt = c.duration / Double(r.steps)
            let initial = try MaskedModeOracle.initial(c, r, spacing: spacing, dt: dt)
            let expected = try MaskedGrid(c,r)
            let material = SurfaceMaterial.rigid
            var vertices:[SIMD3<Double>]=[]
            var faces:[RoomMesh.Face]=[]
            for box in c.boxes {
                let lo=box.minimum,hi=box.maximum,offset=vertices.count
                vertices += [[lo[0],lo[1],lo[2]],[hi[0],lo[1],lo[2]],[hi[0],hi[1],lo[2]],[lo[0],hi[1],lo[2]],[lo[0],lo[1],hi[2]],[hi[0],lo[1],hi[2]],[hi[0],hi[1],hi[2]],[lo[0],hi[1],hi[2]]].map{SIMD3<Double>($0)}
                for corners in [[0,3,7,4],[1,5,6,2],[0,4,5,1],[3,2,6,7],[0,1,2,3],[4,7,6,5]] {
                    faces.append(RoomMesh.Face(corners:corners.map{$0+offset},material:0))
                }
            }
            var room=ShoeboxRoom(size:SIMD3<Double>(c.lengths),material:material)
            room.mesh=RoomMesh(vertices:vertices,faces:faces,materials:[material])
            let atmosphere=Atmosphere(temperatureCelsius:pow(c.speed/331.3,2)*273.15-273.15,relativeHumidity:0,pressureKilopascals:101.325)
            let solver=WaveSolver(room:room,sampleRate:192000,topFrequency:atmosphere.soundSpeed*Double(r.nx)/(10*c.lengths[0])*(1-1e-9),atmosphere:atmosphere)
            guard solver.cells == SIMD3<Int>(r.dimensions) else {throw BenchmarkFailure.invalidSamples}
            let box=c.boxes[0]
            let source=SIMD3<Double>(zip(box.minimum,box.maximum).map{($0+$1)/2})
            let layout=solver.gridLayout(source:source,receivers:[])
            let expectedFaces=expected.faces
            guard layout.inside == expected.inside, (0..<layout.count).allSatisfy({ index in
                expected.labels[index]<0 || (0..<6).allSatisfy{layout.faces[$0*layout.count+index] == expectedFaces[$0*layout.count+index]}
            }) else {throw BenchmarkFailure.failedConformance("Actual mesh occupancy or rigid face layout disagrees with independent integer boxes")}
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
            let cpu = backend == "cpu" ? SourceMaskedCPU(nx:r.nx,ny:r.ny,nz:r.nz,c:c.speed,dt:dt,spacing:SIMD3<Double>(spacing),layout:layout,pressure:p,u:u,v:v,w:w) : nil
            let gpu = backend == "metal" ? try MaskedGPU(nx:r.nx,ny:r.ny,nz:r.nz,c:c.speed,dt:dt,dx:spacing[0],dy:spacing[1],p:p,u:u,v:v,w:w,layout:layout) : nil
            var done = 0
            var frames: [RigidModeFrame] = []
            for step in r.captures {
                if let cpu {
                    cpu.advance(step - done)
                    (p, u, v, w) = cpu.fields()
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
                            do { vx[i + 1 + (r.nx + 1) * (j + r.ny * k)] = Double(u[at]) }
                            do { vy[i + r.nx * (j + 1 + (r.ny + 1) * k)] = Double(v[at]) }
                            do { vz[i + r.nx * (j + r.ny * (k + 1))] = Double(w[at]) }
                        }
                    }
                }
                frames.append(
                    RigidModeFrame(step: step, p: p.map { Double($0) * c.density }, u: vx, v: vy, w: vz))
            }
            return MaskedModeHistory(fields:RigidModeHistory(spacing: spacing, dt: dt, frames: frames),inside:layout.inside,faces:layout.faces)
        }
    }
}
