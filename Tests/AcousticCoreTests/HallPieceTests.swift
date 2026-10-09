import Foundation
import Testing
import simd

@testable import AcousticCore

@Suite("Pieces of air")
struct HallPieceTests {
    static let blank = RoomResponseSettings(
        room: ShoeboxRoom(size: [5, 4, 3], material: .rigid),
        source: RoomPoint(name: "S", position: [1, 1, 1]),
        receivers: [RoomPoint(name: "L", position: [2, 2, 1])])

    static func hall(_ id: String) throws -> ShoeboxRoom {
        try #require(RoomPresets.all.first { $0.id == id }).applied(to: blank).room
    }

    static func box(_ piece: HallPiece) -> (low: SIMD3<Double>, high: SIMD3<Double>)? {
        guard case .box(let low, let high, _) = piece.shape else { return nil }
        return (low, high)
    }

    /// Whether two meshes have the same faces, materials and labels, with corners within a nanometre: a
    /// mesh rebuilt from pieces that have moved differs from one moved after building in rounding only.
    static func same(_ a: RoomMesh?, _ b: RoomMesh?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        return a.faces == b.faces && a.materials == b.materials && a.labels == b.labels
            && a.vertices.count == b.vertices.count
            && zip(a.vertices, b.vertices).allSatisfy { simd_distance($0, $1) < 1e-9 }
    }

    @Test(
        "The hall presets keep their pieces, in the mesh's coordinates, and rebuild the same mesh from them")
    func presetsKeepPieces() throws {
        for id in ["shoebox-concert-hall", "raked-auditorium"] {
            let room = try Self.hall(id)
            let mesh = try #require(room.mesh)
            let pieces = try #require(room.pieces)
            #expect(Self.same(pieces.room(materials: mesh.materials, labels: mesh.labels), mesh))
        }
        let shoebox = try #require(try Self.hall("shoebox-concert-hall").pieces)
        #expect(
            shoebox.map(\.name) == [
                "Stage house", "Hall", "Balcony, north side", "Balcony, south side", "Balcony, back",
                "Stalls seating", "Balcony seating",
            ])
        #expect(shoebox.dropFirst().map(\.operation) == [.join, .cut, .cut, .cut, .cut, .cut])
        #expect(
            try #require(try Self.hall("raked-auditorium").pieces).map(\.operation) == [
                .join, .intersect, .cut,
            ])
    }

    @Test("Pieces save and load, and a room saved without them loads without them")
    func coding() throws {
        let room = try Self.hall("raked-auditorium")
        let decoded = try JSONDecoder().decode(ShoeboxRoom.self, from: JSONEncoder().encode(room))
        #expect(decoded == room)
        var plain = room
        plain.pieces = nil
        let old = try JSONDecoder().decode(ShoeboxRoom.self, from: JSONEncoder().encode(plain))
        #expect(old.pieces == nil && old.mesh == room.mesh)
    }

    @Test("Pieces that are not well formed, or name materials the room lacks, make no room")
    func malformed() {
        let materials = [SurfaceMaterial.rigid]
        let good = HallPiece.box(
            "Air", .join, [0, 0, 0], [4, 3, 2.5], materials: Array(repeating: 0, count: 6))
        #expect([good].room(materials: materials) != nil)
        #expect([HallPiece]().room(materials: materials) == nil)
        let flat = HallPiece.box(
            "Flat", .join, [0, 0, 0], [4, 3, 0], materials: Array(repeating: 0, count: 6))
        #expect([flat].room(materials: materials) == nil)
        let unknown = HallPiece.box(
            "Air", .join, [0, 0, 0], [4, 3, 2.5], materials: Array(repeating: 1, count: 6))
        #expect([unknown].room(materials: materials) == nil)
        let gone = HallPiece.box(
            "All", .cut, [-1, -1, -1], [5, 4, 3.5], materials: Array(repeating: 0, count: 6))
        #expect([good, gone].room(materials: materials) == nil)
    }

    @Test("Pushing a plane stretches the pieces that bound it and carries cut-outs resting on nothing")
    func pushShoebox() throws {
        let room = try Self.hall("shoebox-concert-hall")
        let pieces = try #require(room.pieces)
        let hall = try #require(Self.box(pieces[1]))
        // The floor down half a metre: the hall deepens, and the stalls' seating moves down with it,
        // keeping its centimetre.
        let floor = try #require(pieces.pushing(plane: [0, 0, 1], offset: hall.low.z, by: [0, 0, -0.5]))
        #expect(Self.box(floor[1])?.low.z == hall.low.z - 0.5 && Self.box(floor[1])?.high == hall.high)
        let stalls = try #require(Self.box(floor[5]))
        #expect(
            abs(stalls.low.z - (hall.low.z - 0.5)) < 1e-9 && abs(stalls.high.z - stalls.low.z - 0.01) < 1e-9)
        // The back wall out 2 m: the side balconies lengthen, as they reach the front wall; the back
        // balcony and the seating on it move back whole.
        let back = try #require(pieces.pushing(plane: [-1, 0, 0], offset: -hall.high.x, by: [2, 0, 0]))
        for side in [2, 3] {
            let (before, after) = (try #require(Self.box(pieces[side])), try #require(Self.box(back[side])))
            #expect(after.low == before.low && after.high == before.high + [2, 0, 0])
        }
        for carried in [4, 6] {
            let (before, after) = (
                try #require(Self.box(pieces[carried])), try #require(Self.box(back[carried]))
            )
            #expect(after.low == before.low + [2, 0, 0] && after.high == before.high + [2, 0, 0])
        }
        #expect(Self.box(back[5])! == Self.box(pieces[5])!)
        let rebuilt = try #require(back.room(materials: room.mesh!.materials))
        #expect(abs(rebuilt.bounds.max.x - hall.high.x - 2) < 1e-9)
        // Pulled in past the stage's front: the hall would turn inside out.
        #expect(pieces.pushing(plane: [-1, 0, 0], offset: -hall.high.x, by: [-40, 0, 0]) == nil)
        // A plane no piece lies on.
        #expect(pieces.pushing(plane: [0, 0, 1], offset: 3.21, by: [0, 0, 1]) == nil)
    }

    @Test("Pushing a plane moves an extrusion's sides on it, sloping or square, and its ends")
    func pushRaked() throws {
        let room = try Self.hall("raked-auditorium")
        let pieces = try #require(room.pieces)
        let mesh = try #require(room.mesh)
        let back = mesh.bounds.max.x
        let pushed = try #require(pieces.pushing(plane: [-1, 0, 0], offset: -back, by: [1.5, 0, 0]))
        let rebuilt = try #require(pushed.room(materials: mesh.materials))
        #expect(abs(rebuilt.bounds.max.x - back - 1.5) < 1e-9)
        #expect(rebuilt.volume > mesh.volume)
        // The sloping ceiling raised half a metre along its normal.
        let ceiling = try #require(
            mesh.faces.indices.first {
                let n = mesh.normalAndArea($0).normal
                return n.z < -0.9 && n.z > -0.999 && mesh.faces[$0].material == HallShapes.ceiling
            })
        let normal = mesh.normalAndArea(ceiling).normal
        let offset = simd_dot(normal, mesh.vertices[mesh.faces[ceiling].corners[0]])
        let raised = try #require(pieces.pushing(plane: normal, offset: offset, by: -normal * 0.5))
        let higher = try #require(raised.room(materials: mesh.materials))
        #expect(higher.volume > mesh.volume)
        #expect(higher.bounds.max.z > mesh.bounds.max.z)
    }

    @Test("Fitting a mesh to the origin moves its pieces with it")
    func fitting() throws {
        let room = try Self.hall("shoebox-concert-hall")
        var moved = room
        moved.mesh!.vertices = room.mesh!.vertices.map { $0 + [3, -2, 1] }
        moved.pieces = room.pieces!.map { $0.translated(by: [3, -2, 1]) }
        let fitted = moved.fittingMesh()
        #expect(Self.same(fitted.mesh, room.mesh))
        for (a, b) in zip(fitted.pieces!, room.pieces!) {
            let (p, q) = (try #require(Self.box(a)), try #require(Self.box(b)))
            #expect(simd_distance(p.low, q.low) < 1e-9 && simd_distance(p.high, q.high) < 1e-9)
        }
    }
}
