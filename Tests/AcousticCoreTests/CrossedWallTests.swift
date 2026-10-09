import Foundation
import Testing
import simd

@testable import AcousticCore

@Suite("Directed mesh wall assignment")
struct CrossedWallTests {
    private func absorber(_ xi: Double) -> SurfaceMaterial {
        .uniform(8 / xi * (1 + 1 / (1 + xi) - 2 / xi * log(1 + xi)), name: "Independent impedance")
    }

    private func solver(_ room: ShoeboxRoom, _ n: Int = 64) -> WaveSolver {
        WaveSolver(
            room: room, sampleRate: 768_000,
            topFrequency: Atmosphere.standard.soundSpeed * Double(n) / (10 * room.size.x)
                * (1 - 1e-9), atmosphere: .standard)
    }

    private func room(_ slope: Double) -> ShoeboxRoom {
        let intercept = slope == 0 ? 0.4 : 0.45
        let plan = FloorPlan(
            corners: [[0, 0], [intercept, 0], [intercept - slope * 0.37, 0.37], [0, 0.37]],
            walls: [absorber(5), absorber(3), absorber(7), absorber(11)])
        var room = ShoeboxRoom(size: [0.5, 0.37, 0.00390625], material: .rigid)
        room.plan = plan
        return room
    }

    @Test("Thin aligned and tilted extrusions retain every plan coefficient", arguments: [0.0, 0.5])
    func thinExtrusion(slope: Double) {
        let plan = room(slope)
        var mesh = plan
        mesh.mesh = .extruding(plan.plan!, height: plan.size.z, floor: .rigid, ceiling: .rigid)
        mesh.plan = nil
        for n in [32, 64] {
            let a = solver(plan, n).gridLayout(source: plan.size / 2, receivers: [])
            let b = solver(mesh, n).gridLayout(source: plan.size / 2, receivers: [])
            #expect(a.inside == b.inside)
            #expect(a.faces == b.faces)
        }
    }

    @Test("An open thin side uses air impedance while caps remain rigid")
    func thinOpening() {
        var room = room(0)
        let plan = FloorPlan(corners: room.plan!.corners, material: .rigid)
        room.plan = nil
        room.mesh = .extruding(plan, height: room.size.z, floor: .rigid, ceiling: .rigid)
        room.mesh!.faces[1].open = true
        let wave = solver(room)
        let layout = wave.gridLayout(source: room.size / 2, receivers: [])
        let expected = Float(wave.atmosphere.soundSpeed * wave.timeStep / (2 * wave.spacing.x))
        let positive = layout.faces.filter { $0 > 0 }
        // The entire rectangular east side: ny*nz faces, even though each cap is closer.
        #expect(positive.count == wave.cells.y * wave.cells.z)
        #expect(positive.allSatisfy { $0 == expected })
        #expect(layout.faces[(4 * layout.count)...].allSatisfy { $0 <= 0 })
    }

    @Test("Physical assignment is invariant to mesh face and material storage order")
    func storageOrder() {
        var room = room(0.5)
        room.mesh = .extruding(room.plan!, height: room.size.z, floor: .rigid, ceiling: .rigid)
        room.plan = nil
        let a = solver(room).gridLayout(source: room.size / 2, receivers: [])
        room.mesh!.faces.reverse()
        let count = room.mesh!.materials.count
        room.mesh!.materials.reverse()
        for i in room.mesh!.faces.indices {
            room.mesh!.faces[i].material = count - 1 - room.mesh!.faces[i].material
        }
        let b = solver(room).gridLayout(source: room.size / 2, receivers: [])
        #expect(a.inside == b.inside && a.faces == b.faces)
    }

    @Test("Rotated thin slab matches independent local-box exits with six materials")
    func rotatedSlab() {
        let lengths = SIMD3<Double>(0.25, 0.2, 0.005)
        let half = lengths / 2
        let centre = SIMD3<Double>(0.25, 0.185, 0.09)
        let rotation = simd_quatd(angle: 0.37, axis: simd_normalize(SIMD3<Double>(1, 2, 3)))
        let xis = [3.0, 4, 5, 6, 7, 8]
        var mesh = RoomMesh.box(
            lengths,
            materials: Dictionary(
                uniqueKeysWithValues: Surface.allCases.enumerated().map {
                    ($0.element, absorber(xis[$0.offset]))
                }))
        mesh.vertices = mesh.vertices.map { rotation.act($0 - half) + centre }
        var room = ShoeboxRoom(size: [0.5, 0.37, 0.18], material: .rigid)
        room.mesh = mesh
        let wave = solver(room)
        let layout = wave.gridLayout(source: centre, receivers: [])
        let nx = wave.cells.x
        let ny = wave.cells.y
        var checked = 0
        for cell in 0..<layout.count {
            let point =
                (SIMD3(Double(cell % nx), Double((cell / nx) % ny), Double(cell / (nx * ny))) + 0.5)
                * wave.spacing
            let local = rotation.inverse.act(point - centre)
            let inside = (0..<3).allSatisfy { abs(local[$0]) < half[$0] }
            #expect((layout.inside[cell] == 1) == inside)
            guard inside else { continue }
            for side in 0..<6 where layout.faces[side * layout.count + cell] >= 0 {
                let axis = side / 2
                var delta = SIMD3<Double>(repeating: 0)
                delta[axis] = (side % 2 == 0 ? -1 : 1) * wave.spacing[axis]
                let localDelta = rotation.inverse.act(delta)
                // Independent box slabs: the first positive exit in local material coordinates.
                var best = Double.infinity
                var physicalFace = -1
                for a in 0..<3 where localDelta[a] != 0 {
                    let positive = localDelta[a] > 0
                    let t = ((positive ? half[a] : -half[a]) - local[a]) / localDelta[a]
                    if t > 0 && t < best {
                        best = t
                        physicalFace = 2 * a + (positive ? 1 : 0)
                    }
                }
                #expect(best <= 1 + 1e-9 && physicalFace >= 0)
                guard physicalFace >= 0 else { continue }
                var localNormal = SIMD3<Double>(repeating: 0)
                localNormal[physicalFace / 2] = physicalFace % 2 == 0 ? -1 : 1
                let normal = rotation.act(localNormal)
                let weight = 1 / (abs(normal.x) + abs(normal.y) + abs(normal.z))
                let expected =
                    Float(
                        wave.atmosphere.soundSpeed * wave.timeStep
                            / (2 * xis[physicalFace] * wave.spacing[axis])) * Float(weight)
                let actual = layout.faces[side * layout.count + cell]
                #expect(abs(Double(actual / expected) - 1) < 2e-6)
                checked += 1
            }
        }
        #expect(checked > 500)
    }
}
