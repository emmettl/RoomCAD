import Foundation
import Metal
import simd

@testable import AcousticCore

/// The wave solver's scheme on the GPU: the same staggered grid, walls and sampling as the CPU solver,
/// for boxes and floor plans alike, with each cell's boundary faces precomputed.
final class MetalWaveSolver: MetalSimulation, @unchecked Sendable {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let velocity: MTLComputePipelineState
    private let pressure: MTLComputePipelineState
    private let inject: MTLComputePipelineState
    private let sample: MTLComputePipelineState

    /// The system's GPU, or nil if there is none or its kernels do not compile.
    static let shared: MetalWaveSolver? = {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        return try? MetalWaveSolver(device: device)
    }()

    /// Steps encoded per command buffer; cancellation is checked between buffers.
    static let stepsPerBuffer = 128

    init(device: MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            throw AcousticError.invalid("No GPU command queue.")
        }
        self.queue = queue
        let library = try device.makeLibrary(source: Self.source, options: nil)
        func pipeline(_ name: String) throws -> MTLComputePipelineState {
            guard let function = library.makeFunction(name: name) else {
                throw AcousticError.invalid("Missing GPU function \(name).")
            }
            return try device.makeComputePipelineState(function: function)
        }
        velocity = try pipeline("waveVelocity")
        pressure = try pipeline("wavePressure")
        inject = try pipeline("waveInject")
        sample = try pipeline("waveSample")
    }

    struct Grid {
        var nx, ny, nz: UInt32
        var kx, ky, kz: Float
        var bx, by, bz: Float
    }

    /// Simulates like `WaveSolver.simulate`, returning each receiver's microphone output after each step,
    /// or nil if `stop` asks it to, `abandon` gives up on it, or the GPU fails. Between command buffers,
    /// `abandon` is passed the steps done and the seconds taken so far.
    func simulate(
        _ solver: WaveSolver, source: SIMD3<Double>,
        receivers: [(position: SIMD3<Double>, microphone: Microphone)],
        steps: Int, stop: @Sendable () -> Bool,
        abandon: (_ done: Int, _ elapsed: TimeInterval) -> Bool = { _, _ in false }
    ) -> [[Double]]? {
        let started = Date()
        let layout = solver.gridLayout(source: source, receivers: receivers)
        let count = layout.count
        let c = solver.atmosphere.soundSpeed
        let dt = solver.timeStep
        let spacing = solver.spacing
        var grid = Grid(
            nx: UInt32(solver.cells.x), ny: UInt32(solver.cells.y), nz: UInt32(solver.cells.z),
            kx: Float(dt / spacing.x), ky: Float(dt / spacing.y), kz: Float(dt / spacing.z),
            bx: Float(c * c * dt / spacing.x), by: Float(c * c * dt / spacing.y),
            bz: Float(c * c * dt / spacing.z))
        func buffer<T>(_ values: [T]) -> MTLBuffer? {
            values.withUnsafeBytes {
                device.makeBuffer(
                    bytes: $0.baseAddress!, length: max($0.count, 4), options: .storageModeShared)
            }
        }
        func zeros(_ floats: Int) -> MTLBuffer? {
            let buffer = device.makeBuffer(length: max(floats, 1) * 4, options: .storageModeShared)
            if let buffer { memset(buffer.contents(), 0, buffer.length) }
            return buffer
        }
        let pulse = (0..<steps).map { Float(solver.pulse((Double($0) + 0.5) * dt)) }
        guard let p = zeros(count), let ux = zeros(count), let uy = zeros(count), let uz = zeros(count),
            let inside = buffer(layout.inside), let faces = buffer(layout.faces), let q = buffer(pulse),
            let sourceCells = buffer(layout.sourceCells.map(UInt32.init)),
            let sourceWeights = buffer(layout.sourceWeights),
            let receiverCells = buffer(layout.receiverCells.map(UInt32.init)),
            let receiverWeights = buffer(layout.receiverWeights),
            let velocityCells = buffer(layout.velocityCells.map(UInt32.init)), let axes = buffer(layout.axes),
            let output = zeros(receivers.count * steps),
            let velocityOutput = zeros(receivers.count * (steps + 1))
        else { return nil }

        let threads = MTLSize(width: Int(grid.nx), height: Int(grid.ny), depth: Int(grid.nz))
        let group = MTLSize(width: 32, height: 4, depth: 2)
        var sourceCount = UInt32(layout.sourceCells.count)
        var receiverCount = UInt32(receivers.count)
        var totalSteps = UInt32(steps)
        var start = 0
        while start < steps {
            if stop() { return nil }
            guard let commands = queue.makeCommandBuffer(), let encoder = commands.makeComputeCommandEncoder()
            else {
                return nil
            }
            for n in start..<min(start + Self.stepsPerBuffer, steps) {
                var step = UInt32(n)
                encoder.setComputePipelineState(velocity)
                encoder.setBuffer(p, offset: 0, index: 0)
                encoder.setBuffer(ux, offset: 0, index: 1)
                encoder.setBuffer(uy, offset: 0, index: 2)
                encoder.setBuffer(uz, offset: 0, index: 3)
                encoder.setBuffer(inside, offset: 0, index: 4)
                encoder.setBytes(&grid, length: MemoryLayout<Grid>.stride, index: 5)
                encoder.dispatchThreads(threads, threadsPerThreadgroup: group)

                encoder.setComputePipelineState(pressure)
                encoder.setBuffer(faces, offset: 0, index: 5)
                encoder.setBytes(&grid, length: MemoryLayout<Grid>.stride, index: 6)
                encoder.dispatchThreads(threads, threadsPerThreadgroup: group)

                encoder.setComputePipelineState(inject)
                encoder.setBuffer(p, offset: 0, index: 0)
                encoder.setBuffer(q, offset: 0, index: 1)
                encoder.setBuffer(sourceCells, offset: 0, index: 2)
                encoder.setBuffer(sourceWeights, offset: 0, index: 3)
                encoder.setBytes(&step, length: 4, index: 4)
                encoder.setBytes(&sourceCount, length: 4, index: 5)
                encoder.dispatchThreads(
                    MTLSize(width: layout.sourceCells.count, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1))

                encoder.setComputePipelineState(sample)
                encoder.setBuffer(p, offset: 0, index: 0)
                encoder.setBuffer(ux, offset: 0, index: 1)
                encoder.setBuffer(uy, offset: 0, index: 2)
                encoder.setBuffer(uz, offset: 0, index: 3)
                encoder.setBuffer(receiverCells, offset: 0, index: 4)
                encoder.setBuffer(receiverWeights, offset: 0, index: 5)
                encoder.setBuffer(velocityCells, offset: 0, index: 6)
                encoder.setBuffer(axes, offset: 0, index: 7)
                encoder.setBuffer(output, offset: 0, index: 8)
                encoder.setBuffer(velocityOutput, offset: 0, index: 9)
                encoder.setBytes(&grid, length: MemoryLayout<Grid>.stride, index: 10)
                encoder.setBytes(&step, length: 4, index: 11)
                encoder.setBytes(&totalSteps, length: 4, index: 12)
                encoder.setBytes(&receiverCount, length: 4, index: 13)
                encoder.dispatchThreads(
                    MTLSize(width: receivers.count, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
            }
            encoder.endEncoding()
            commands.commit()
            commands.waitUntilCompleted()
            guard commands.status == .completed else { return nil }
            if solver.gpuDelay > 0 { Thread.sleep(forTimeInterval: solver.gpuDelay) }
            start += Self.stepsPerBuffer
            if start < steps, abandon(start, Date().timeIntervalSince(started)) { return nil }
        }

        let pressures = output.contents().bindMemory(to: Float.self, capacity: receivers.count * steps)
        let velocities = velocityOutput.contents().bindMemory(
            to: Float.self, capacity: receivers.count * (steps + 1))
        return receivers.indices.map { r in
            let microphone = receivers[r].microphone
            let pressure = (0..<steps).map { Double(pressures[r * steps + $0]) }
            guard !microphone.isOmni else { return pressure }
            let a = microphone.pattern.omniShare
            let v = { (n: Int) in Double(velocities[r * (steps + 1) + n]) }
            return (0..<steps).map { n in
                let average = n + 2 <= steps ? (v(n + 1) + v(n + 2)) / 2 : v(n + 1)
                return a * pressure[n] - (1 - a) * c * average
            }
        }
    }

    static let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct Grid { uint nx, ny, nz; float kx, ky, kz; float bx, by, bz; };

        // Velocity on faces between two simulated cells; others stay zero and are walls.
        kernel void waveVelocity(device const float* p [[buffer(0)]], device float* ux [[buffer(1)]],
                                 device float* uy [[buffer(2)]], device float* uz [[buffer(3)]],
                                 device const uchar* inside [[buffer(4)]], constant Grid& g [[buffer(5)]],
                                 uint3 id [[thread_position_in_grid]]) {
            if (id.x >= g.nx || id.y >= g.ny || id.z >= g.nz) return;
            uint plane = g.nx * g.ny;
            uint at = id.x + g.nx * id.y + plane * id.z;
            if (!inside[at]) return;
            float here = p[at];
            if (id.x + 1 < g.nx && inside[at + 1]) ux[at] -= g.kx * (p[at + 1] - here);
            if (id.y + 1 < g.ny && inside[at + g.nx]) uy[at] -= g.ky * (p[at + g.nx] - here);
            if (id.z + 1 < g.nz && inside[at + plane]) uz[at] -= g.kz * (p[at + plane] - here);
        }

        // Pressure from the divergence, with each boundary face's semi-implicit wall term; a face value
        // below zero means a neighbour.
        kernel void wavePressure(device float* p [[buffer(0)]], device const float* ux [[buffer(1)]],
                                 device const float* uy [[buffer(2)]], device const float* uz [[buffer(3)]],
                                 device const uchar* inside [[buffer(4)]], device const float* faces [[buffer(5)]],
                                 constant Grid& g [[buffer(6)]], uint3 id [[thread_position_in_grid]]) {
            if (id.x >= g.nx || id.y >= g.ny || id.z >= g.nz) return;
            uint plane = g.nx * g.ny;
            uint count = plane * g.nz;
            uint at = id.x + g.nx * id.y + plane * id.z;
            if (!inside[at]) return;
            float divergence = 0;
            float wall = 0;
            float f;
            f = faces[at];             if (f < 0) divergence -= g.bx * ux[at - 1];     else wall += f;
            f = faces[count + at];     if (f < 0) divergence += g.bx * ux[at];         else wall += f;
            f = faces[2 * count + at]; if (f < 0) divergence -= g.by * uy[at - g.nx];  else wall += f;
            f = faces[3 * count + at]; if (f < 0) divergence += g.by * uy[at];         else wall += f;
            f = faces[4 * count + at]; if (f < 0) divergence -= g.bz * uz[at - plane]; else wall += f;
            f = faces[5 * count + at]; if (f < 0) divergence += g.bz * uz[at];         else wall += f;
            p[at] = ((1 - wall) * p[at] - divergence) / (1 + wall);
        }

        // Volume velocity at the source, weights already scaled by c² dt / V.
        kernel void waveInject(device float* p [[buffer(0)]], device const float* q [[buffer(1)]],
                               device const uint* cells [[buffer(2)]], device const float* weights [[buffer(3)]],
                               constant uint& step [[buffer(4)]], constant uint& count [[buffer(5)]],
                               uint i [[thread_position_in_grid]]) {
            if (i >= count) return;
            p[cells[i]] += q[step] * weights[i];
        }

        // Pressure at each receiver, and velocity along its microphone's axis at its cell.
        kernel void waveSample(device const float* p [[buffer(0)]], device const float* ux [[buffer(1)]],
                               device const float* uy [[buffer(2)]], device const float* uz [[buffer(3)]],
                               device const uint* cells [[buffer(4)]], device const float* weights [[buffer(5)]],
                               device const uint* velocityCells [[buffer(6)]], device const float* axes [[buffer(7)]],
                               device float* output [[buffer(8)]], device float* velocityOutput [[buffer(9)]],
                               constant Grid& g [[buffer(10)]], constant uint& step [[buffer(11)]],
                               constant uint& steps [[buffer(12)]], constant uint& receivers [[buffer(13)]],
                               uint r [[thread_position_in_grid]]) {
            if (r >= receivers) return;
            float value = 0;
            for (uint k = 0; k < 8; k++) value += p[cells[8 * r + k]] * weights[8 * r + k];
            output[r * steps + step] = value;
            uint at = velocityCells[r];
            uint plane = g.nx * g.ny;
            float3 u = float3((ux[at - 1] + ux[at]) / 2, (uy[at - g.nx] + uy[at]) / 2, (uz[at - plane] + uz[at]) / 2);
            velocityOutput[r * (steps + 1) + step + 1] = dot(u, float3(axes[3 * r], axes[3 * r + 1], axes[3 * r + 2]));
        }
        """
}

// Verification-only original selection; application products do not compile this class.
extension WaveSolver {
    func usingOriginalMetal() -> Self {
        var result = self
        result.metalBackend = MetalWaveSolver.shared
        return result
    }
}
