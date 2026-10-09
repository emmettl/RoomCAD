import Foundation
import Testing
import simd

@testable import AcousticCore

@Suite("Prescribed-load wall admittance geometry")
struct WallAreaTests {
    private func absorber(_ xi: Double) -> SurfaceMaterial {
        // Independent statistical-incidence integral for a real normalized impedance.
        let alpha = 8 / xi * (1 + 1 / (1 + xi) - 2 / xi * log(1 + xi))
        return .uniform(alpha, name: "Prescribed impedance")
    }

    private func solver(_ room: ShoeboxRoom, _ n: Int) -> WaveSolver {
        WaveSolver(
            room: room, sampleRate: 192_000,
            topFrequency: Atmosphere.standard.soundSpeed * Double(n) / (10 * room.size.x)
                * (1 - 1e-9), atmosphere: .standard)
    }

    /// Sum actual layout wall work under a prescribed surface load. Pressure is specified at
    /// each staircase face; this is a geometry quadrature, not a free-wave initial condition.
    private func admittance(
        _ solver: WaveSolver, pressure: (SIMD3<Double>) -> Double = { _ in 1 }
    ) -> Double {
        let layout = solver.gridLayout(source: solver.room.size / 2, receivers: [])
        let d = solver.spacing
        let volume = d.x * d.y * d.z
        let steps: [SIMD3<Double>] = [
            [-1, 0, 0], [1, 0, 0], [0, -1, 0], [0, 1, 0], [0, 0, -1], [0, 0, 1],
        ]
        var integral = 0.0
        for k in 0..<solver.cells.z {
            for j in 0..<solver.cells.y {
                for i in 0..<solver.cells.x {
                    let at = i + solver.cells.x * (j + solver.cells.y * k)
                    guard layout.inside[at] == 1 else { continue }
                    let centre = (SIMD3(Double(i), Double(j), Double(k)) + 0.5) * d
                    for side in 0..<6 {
                        let beta = Double(layout.faces[side * layout.count + at])
                        guard beta > 0 else { continue }
                        let p = pressure(centre + steps[side] * d / 2)
                        integral +=
                            2 * beta * volume * p * p
                            / (solver.atmosphere.soundSpeed * solver.timeStep)
                    }
                }
            }
        }
        return integral
    }

    private func cylinder(_ mesh: Bool, split: Bool = false, open: Bool = false) -> ShoeboxRoom {
        let segments = 1024
        let corners = (0..<segments).map { i in
            let theta = 2 * Double.pi * Double(i) / Double(segments)
            return SIMD2<Double>(0.125 + 0.09375 * cos(theta), 0.125 + 0.09375 * sin(theta))
        }
        let materials = (0..<segments).map { i in
            let theta = 2 * Double.pi * (Double(i) + 0.5) / Double(segments)
            return absorber(split && cos(theta) < 0 ? 6 : 3)
        }
        let plan = FloorPlan(corners: corners, walls: materials)
        var room = ShoeboxRoom(size: [0.25, 0.25, 0.125], material: .rigid)
        if mesh {
            room.mesh = .extruding(plan, height: 0.125, floor: .rigid, ceiling: .rigid)
            if open {
                for i in 0..<segments { room.mesh!.faces[i].open = true }
            }
        } else {
            room.plan = plan
        }
        return room
    }

    @Test("Circle side area passes unchanged 0.5 percent gate for mesh and plan", arguments: [false, true])
    func cylinderArea(mesh: Bool) {
        let room = cylinder(mesh)
        for n in [16, 32, 64] {
            let integral = admittance(solver(room, n))
            let expected = 2 * Double.pi * 0.09375 * 0.125 / 3
            #expect(abs(integral / expected - 1) < 0.005, "n=\(n), relative=\(integral / expected - 1)")
        }
    }

    @Test("Non-uniform pressure and two materials retain local wall work", arguments: [false, true])
    func loadedMaterials(mesh: Bool) {
        let room = cylinder(mesh, split: true)
        let a = 0.3
        // On a half circle: integral cos(theta) = +/-2, integral cos²(theta) = pi/2.
        let expected =
            0.09375 * 0.125
            * ((Double.pi * (1 + a * a / 2) + 4 * a) / 3
                + (Double.pi * (1 + a * a / 2) - 4 * a) / 6)
        var errors: [Double] = []
        for n in [16, 32, 64] {
            let integral = admittance(solver(room, n)) { point in
                let radial = SIMD2(point.x - 0.125, point.y - 0.125)
                return 1 + a * radial.x / simd_length(radial)
            }
            errors.append(abs(integral / expected - 1))
        }
        #expect(errors.allSatisfy { $0 < 0.01 })
        #expect(errors.last! < errors.first!)
    }

    @Test("Curved open faces use air impedance with the same geometric measure")
    func curvedOpening() {
        let room = cylinder(true, open: true)
        let expected = 2 * Double.pi * 0.09375 * 0.125
        #expect(abs(admittance(solver(room, 32)) / expected - 1) < 0.005)
    }

    @Test("Rotated square area is orientation independent under refinement", arguments: [false, true])
    func rotatedSquare(mesh: Bool) {
        for angle in [0.0, Double.pi / 4, atan(0.5)] {
            let half = 0.0625
            let corners: [SIMD2<Double>] = [[-half, -half], [half, -half], [half, half], [-half, half]]
            let turned = corners.map { p in
                SIMD2(
                    0.125 + cos(angle) * p.x - sin(angle) * p.y,
                    0.125 + sin(angle) * p.x + cos(angle) * p.y)
            }
            let plan = FloorPlan(corners: turned, material: absorber(3))
            var room = ShoeboxRoom(size: [0.25, 0.25, 0.125], material: .rigid)
            if mesh {
                room.mesh = .extruding(plan, height: 0.125, floor: .rigid, ceiling: .rigid)
            } else {
                room.plan = plan
            }
            let expected = 8 * half * 0.125 / 3
            let coarse = abs(admittance(solver(room, 64)) / expected - 1)
            let fine = abs(admittance(solver(room, 128)) / expected - 1)
            // Finite stair endpoints still misplace polygon corners. Refine them separately
            // from the local planar area rule; retain a 2% finest-grid area bound.
            #expect(
                coarse < 0.03 && fine < 0.02 && fine <= coarse + 1e-7,
                "angle=\(angle), errors=\(coarse),\(fine)")
        }
    }

    @Test("A tilted cube exercises all three normal components and anisotropic spacing")
    func tiltedCube() {
        let side = 0.125
        var mesh = RoomMesh.box(
            SIMD3(repeating: side),
            materials: Dictionary(uniqueKeysWithValues: Surface.allCases.map { ($0, absorber(3)) }))
        let rotation = simd_quatd(angle: 0.37, axis: simd_normalize(SIMD3<Double>(1, 2, 3)))
        mesh.vertices = mesh.vertices.map {
            rotation.act($0 - SIMD3(repeating: side / 2)) + SIMD3<Double>(0.125, 0.125, 0.1)
        }
        var room = ShoeboxRoom(size: [0.25, 0.25, 0.2], material: .rigid)
        room.mesh = mesh
        let expected = 6 * side * side / 3
        let coarse = abs(admittance(solver(room, 32)) / expected - 1)
        let fine = abs(admittance(solver(room, 64)) / expected - 1)
        #expect(coarse < 0.06 && fine < 0.03 && fine < coarse, "errors=\(coarse),\(fine)")
    }

    @Test("Axis-aligned plan and mesh coefficients exactly retain box behavior")
    func alignedParity() {
        let room = ShoeboxRoom(size: [0.25, 0.25, 0.125], material: absorber(3))
        var plan = room
        plan.plan = .rectangle([0.25, 0.25], material: absorber(3))
        var mesh = room
        mesh.mesh = .box(
            room.size, materials: Dictionary(uniqueKeysWithValues: Surface.allCases.map { ($0, absorber(3)) })
        )
        let baseline = solver(room, 16).gridLayout(source: room.size / 2, receivers: [])
        for variant in [plan, mesh] {
            let actual = solver(variant, 16).gridLayout(source: room.size / 2, receivers: [])
            #expect(actual.inside == baseline.inside && actual.faces == baseline.faces)
        }
    }
}
