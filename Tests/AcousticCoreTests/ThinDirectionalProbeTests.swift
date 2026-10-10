import Foundation
import LinearAcoustics
import LinearAcousticsMetal
import Metal
import Testing
import simd

@testable import AcousticCore

@Suite("Directional probes on minimal wave dimensions")
struct ThinDirectionalProbeTests {
    private func solver(axis: Int, representation: Int = 0) -> WaveSolver {
        var size = SIMD3<Double>(repeating: 4)
        size[axis] = 1
        var room = ShoeboxRoom(size: size, material: .rigid)
        if representation == 1 {
            room.plan = .rectangle([size.x, size.y], material: .rigid)
        } else if representation == 2 {
            room.mesh = .box(
                size,
                materials: Dictionary(
                    uniqueKeysWithValues: Surface.allCases.map { ($0, SurfaceMaterial.rigid) }))
        }
        return WaveSolver(
            room: room, sampleRate: 48_000,
            topFrequency: Atmosphere.standard.soundSpeed / 10 * (1 - 1e-9), atmosphere: .standard)
    }

    @Test(
        "Every axis retains valid native minus-face addresses, including lower-wall positions",
        arguments: [0, 1, 2])
    func addresses(axis: Int) {
        let s = solver(axis: axis)
        #expect(s.cells[axis] == 2)
        for position in [SIMD3<Double>(repeating: 0), s.room.size / 2, s.room.size] {
            let cell = s.velocityProbeCell(position)
            #expect(cell[axis] == 1)
            #expect(all(cell .>= 1) && all(cell .< s.cells))
            let layout = s.gridLayout(source: s.room.size / 2, receivers: [(position, .omni)])
            let at = layout.velocityCells[0]
            let plane = s.cells.x * s.cells.y
            #expect(at == cell.x + s.cells.x * (cell.y + s.cells.y * cell.z))
            #expect(at % s.cells.x > 0 && at / s.cells.x % s.cells.y > 0 && at / plane > 0)
            #expect(at - 1 >= 0 && at - s.cells.x >= 0 && at - plane >= 0)
        }
    }

    @Test("Existing interior selections are unchanged on all nonminimal axes")
    func unchangedInterior() {
        let s = WaveSolver(
            room: ShoeboxRoom(size: [4, 5, 6], material: .rigid), sampleRate: 48_000, topFrequency: 200,
            atmosphere: .standard)
        for fraction in [0.0, 0.1, 0.5, 0.9, 1.0] {
            let position = s.room.size * fraction
            let g = position / s.spacing
            let old = SIMD3<Int>(
                min(max(Int(g.x), 1), s.cells.x - 2), min(max(Int(g.y), 1), s.cells.y - 2),
                min(max(Int(g.z), 1), s.cells.z - 2))
            #expect(s.velocityProbeCell(position) == old)
        }
    }

    /// Actual original Metal sampler, with prescribed native fields and no evolution.
    private func originalMetalSample(
        _ device: any MTLDevice, _ s: WaveSolver, _ at: Int,
        _ fields: [[Float]], _ axis: SIMD3<Double>
    ) throws -> (Float, Float) {
        let library = try device.makeLibrary(source: MetalWaveSolver.source, options: nil)
        let function = try #require(library.makeFunction(name: "waveSample"))
        let pipeline = try device.makeComputePipelineState(function: function)
        let queue = try #require(device.makeCommandQueue())
        let commands = try #require(queue.makeCommandBuffer())
        let encoder = try #require(commands.makeComputeCommandEncoder())
        func buffer<T>(_ values: [T]) throws -> any MTLBuffer {
            let result = values.withUnsafeBytes {
                device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
            }
            return try #require(result)
        }
        let inputs = try fields.map(buffer)
        let cells = try buffer(Array(repeating: UInt32(at), count: 8))
        let weights = try buffer([Float](arrayLiteral: 1, 0, 0, 0, 0, 0, 0, 0))
        let velocityCells = try buffer([UInt32(at)])
        let axes = try buffer([Float(axis.x), Float(axis.y), Float(axis.z)])
        let pressure = try buffer([Float(0)])
        let velocity = try buffer([Float(0), 0])
        var grid = MetalWaveSolver.Grid(
            nx: UInt32(s.cells.x), ny: UInt32(s.cells.y), nz: UInt32(s.cells.z), kx: 0, ky: 0, kz: 0, bx: 0,
            by: 0, bz: 0)
        var step: UInt32 = 0
        var steps: UInt32 = 1
        var receivers: UInt32 = 1
        encoder.setComputePipelineState(pipeline)
        for (i, input) in inputs.enumerated() { encoder.setBuffer(input, offset: 0, index: i) }
        for (i, input) in [cells, weights, velocityCells, axes, pressure, velocity].enumerated() {
            encoder.setBuffer(input, offset: 0, index: i + 4)
        }
        encoder.setBytes(&grid, length: MemoryLayout<MetalWaveSolver.Grid>.stride, index: 10)
        encoder.setBytes(&step, length: 4, index: 11)
        encoder.setBytes(&steps, length: 4, index: 12)
        encoder.setBytes(&receivers, length: 4, index: 13)
        encoder.dispatchThreads(
            MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        encoder.endEncoding()
        commands.commit()
        commands.waitUntilCompleted()
        #expect(commands.status == .completed)
        return (
            pressure.contents().load(as: Float.self),
            velocity.contents().bindMemory(to: Float.self, capacity: 2)[1]
        )
    }

    @Test(
        "Closed boundary and internal-face averages have an independent CPU/actual-Metal oracle",
        arguments: [0, 1, 2])
    func nativeOracle(axis: Int) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let s = solver(axis: axis)
        let point = s.spacing * SIMD3<Double>(repeating: 0.5)
        let cell = s.velocityProbeCell(point)
        let layout = s.gridLayout(
            source: s.room.size / 2, receivers: [(point, Microphone(pattern: .figureOfEight))])
        let count = layout.count
        let d = s.cells
        let grid = try PreparedWaveGrid(
            dimensions: d, spacing: s.spacing, soundSpeed: s.atmosphere.soundSpeed, density: 1,
            timeStep: s.timeStep, activeCells: layout.inside, boundaryTerms: layout.faces)
        let p = [Float](repeating: 7, count: count)
        let velocities = (0..<3).map { component in
            (0..<count).map { at -> Float in
                let xyz = SIMD3(at % d.x, at / d.x % d.y, at / (d.x * d.y))
                return xyz[component] == d[component] - 1 ? 0 : Float(component + 2)
            }
        }
        var direction = SIMD3<Double>(repeating: 0)
        direction[axis] = 1
        let at = cell.x + d.x * (cell.y + d.y * cell.z)
        #expect(at == layout.velocityCells[0])
        let observation = try PreparedWaveObservation(
            grid: grid,
            receivers: [
                WaveReceiverStencil(
                    pressureCells: Array(repeating: at, count: 8), pressureWeights: [1, 0, 0, 0, 0, 0, 0, 0],
                    velocityCell: at, velocityAxis: direction)
            ])
        let fields = WaveInitialFields(
            pressureOverDensity: p, velocityX: velocities[0], velocityY: velocities[1],
            velocityZ: velocities[2])
        let cpu = try CPUWaveStepper(grid: grid, initialFields: fields)
        let metal = try MetalWaveStepper(device: device, grid: grid, initialFields: fields)
        let cpuFrame = try cpu.observe(observation)
        let metalFrame = try metal.observe(metal.prepareObservation(observation))
        let original = try originalMetalSample(device, s, at, [p] + velocities, direction)
        let expected = Double(axis + 2) / 2
        #expect(cpuFrame.pressureOverDensity == [7] && cpuFrame.projectedVelocity == [expected])
        #expect(metalFrame.pressureOverDensity == [7] && metalFrame.projectedVelocity == [expected])
        #expect(original.0 == 7 && original.1 == Float(expected))
    }

    @Test(
        "Two-step whole solver output matches hand-derived pressure and final half-step velocity",
        arguments: [0, 1, 2])
    func twoSteps(axis: Int) throws {
        let gpu = try #require(MetalWaveSolver.shared)
        for representation in 0..<3 {
            let s = solver(axis: axis, representation: representation)
            var source = s.spacing * SIMD3<Double>(repeating: 1.5)
            source[axis] = s.spacing[axis] / 2
            var receiver = source
            receiver[axis] = 1.5 * s.spacing[axis]
            let microphone = Microphone(
                pattern: .cardioid, azimuth: axis == 1 ? 90 : 0, elevation: axis == 2 ? 90 : 0)
            let r = [(position: receiver, microphone: microphone)]
            let q = s.pulse(0.5 * s.timeStep)
            let volume = s.spacing.x * s.spacing.y * s.spacing.z
            let c = s.atmosphere.soundSpeed
            let dt = s.timeStep
            let h = s.spacing[axis]
            let initialP: Float =
                representation == 0 ? Float(c * c * dt * q / volume) : Float(q) * Float(c * c * dt / volume)
            let internalFace = Float(dt / h) * initialP
            let pressure = Float(c * c * dt / h) * internalFace
            let expected = 0.5 * Double(pressure) - 0.5 * c * (Double(internalFace) / 2)
            let cpuResult = s.usingOriginalMaskedCPU().simulate(
                source: source, receivers: r, steps: 2, stop: { false })
            let cpu = try #require(cpuResult)[0]
            // The first pressure is zero, but its centred velocity includes step 2's half-step.
            let firstExpected = -0.5 * c * (Double(internalFace) / 4)
            #expect(abs(cpu[0] - firstExpected) < 1e-6 * max(abs(firstExpected), 1e-15))
            #expect(abs(cpu[1] - expected) < 1e-6 * max(abs(expected), 1e-15))
            if representation != 0 {
                let sharedResult = s.usingSharedMaskedCPU().simulate(
                    source: source, receivers: r, steps: 2, stop: { false })
                let shared = try #require(sharedResult)[0]
                #expect(cpu.map(\.bitPattern) == shared.map(\.bitPattern))
            }
            let gpuResult = gpu.simulate(s, source: source, receivers: r, steps: 2, stop: { false })
            let metal = try #require(gpuResult)[0]
            let gpuP = Float(q) * Float(c * c * dt / volume)
            let gpuFace = Float(dt / h) * gpuP
            let gpuPressure = Float(c * c * dt / h) * gpuFace
            let gpuExpected = 0.5 * Double(gpuPressure) - 0.5 * c * Double(gpuFace / 2)
            let gpuFirstExpected = -0.5 * c * (Double(gpuFace / 2) / 2)
            #expect(abs(metal[0] - gpuFirstExpected) < 1e-6 * max(abs(gpuFirstExpected), 1e-15))
            #expect(abs(metal[1] - gpuExpected) < 1e-6 * max(abs(gpuExpected), 1e-15))
        }
    }
}
