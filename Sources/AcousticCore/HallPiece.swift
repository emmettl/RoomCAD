import Foundation
import simd

/// One piece of a room's air: a box or an extruded polygon, joined to the pieces before it, cut out of
/// them or intersected with them (see `Solid`). A room built from pieces keeps them, so that pieces can
/// be added, removed and moved after it is built; its mesh is rebuilt from them. Materials are indices
/// into the mesh's materials.
public struct HallPiece: Codable, Equatable, Sendable, Identifiable {
    public enum Operation: String, Codable, Sendable, CaseIterable {
        case join, cut, intersect
    }

    public enum Shape: Codable, Equatable, Sendable {
        /// Two corners, and six materials in the order -x, +x, -y, +y, -z, +z.
        case box(low: SIMD3<Double>, high: SIMD3<Double>, materials: [Int])
        /// A polygon extruded along an axis, its sides' materials and its ends', lower end first; see
        /// `Solid.extrusion`.
        case extrusion(
            points: [SIMD2<Double>], axis: Int, from: Double, to: Double, sides: [Int], ends: [Int])
    }

    public var id: UUID
    public var name: String
    /// How the piece combines with those before it; the first piece is the air the others start from.
    public var operation: Operation
    public var shape: Shape

    public init(id: UUID = UUID(), name: String, operation: Operation, shape: Shape) {
        self.id = id
        self.name = name
        self.operation = operation
        self.shape = shape
    }

    /// A box piece.
    public static func box(
        _ name: String, _ operation: Operation, _ low: SIMD3<Double>, _ high: SIMD3<Double>, materials: [Int]
    ) -> HallPiece {
        HallPiece(name: name, operation: operation, shape: .box(low: low, high: high, materials: materials))
    }

    /// An extruded piece.
    public static func extrusion(
        _ name: String, _ operation: Operation, _ points: [SIMD2<Double>], along axis: Int, from: Double,
        to: Double, sides: [Int], ends: (Int, Int)
    ) -> HallPiece {
        HallPiece(
            name: name, operation: operation,
            shape: .extrusion(
                points: points, axis: axis, from: from, to: to, sides: sides, ends: [ends.0, ends.1]))
    }

    public var solid: Solid {
        switch shape {
        case .box(let low, let high, let materials):
            .box(low, high, materials: materials)
        case .extrusion(let points, let axis, let from, let to, let sides, let ends):
            .extrusion(points, along: axis, from: from, to: to, sides: sides, ends: (ends[0], ends[1]))
        }
    }

    /// The piece's bounds.
    public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) {
        switch shape {
        case .box(let low, let high, _):
            return (simd_min(low, high), simd_max(low, high))
        case .extrusion:
            let corners = solid.polygons.flatMap(\.vertices)
            return (
                corners.reduce(SIMD3(repeating: .infinity)) { simd_min($0, $1) },
                corners.reduce(SIMD3(repeating: -.infinity)) { simd_max($0, $1) }
            )
        }
    }

    /// Whether the piece's numbers make a solid: finite, a box with some size in every direction, an
    /// extrusion with at least three points, a length, and a material for every side and end.
    public var isWellFormed: Bool {
        switch shape {
        case .box(let low, let high, let materials):
            return materials.count == 6 && all(low .< high)
                && [low, high].allSatisfy { v in
                    (0..<3).allSatisfy { v[$0].isFinite }
                }
        case .extrusion(let points, let axis, let from, let to, let sides, let ends):
            return points.count >= 3 && sides.count == points.count && ends.count == 2
                && (0..<3).contains(axis) && from.isFinite && to.isFinite && from < to
                && points.allSatisfy { $0.x.isFinite && $0.y.isFinite }
        }
    }

    /// The piece moved by `offset`.
    public func translated(by offset: SIMD3<Double>) -> HallPiece {
        var piece = self
        switch shape {
        case .box(let low, let high, let materials):
            piece.shape = .box(low: low + offset, high: high + offset, materials: materials)
        case .extrusion(let points, let axis, let from, let to, let sides, let ends):
            let (a, b) = Self.planeAxes(axis)
            let shift = SIMD2(offset[a], offset[b])
            piece.shape = .extrusion(
                points: points.map { $0 + shift }, axis: axis, from: from + offset[axis],
                to: to + offset[axis],
                sides: sides, ends: ends)
        }
        return piece
    }

    /// The axes of an extruded polygon's points: (y, z) along x, (x, z) along y and (x, y) along z.
    public static func planeAxes(_ axis: Int) -> (Int, Int) {
        switch axis {
        case 0: (1, 2)
        case 1: (0, 2)
        default: (0, 1)
        }
    }
}

extension [HallPiece] {
    /// The air: the first piece, with each later one joined, cut or intersected in turn. Nil if there are
    /// no pieces or one is not well formed.
    public var solid: Solid? {
        guard let first, allSatisfy(\.isWellFormed) else { return nil }
        return dropFirst().reduce(first.solid) { air, piece in
            switch piece.operation {
            case .join: air.union(piece.solid)
            case .cut: air.subtracting(piece.solid)
            case .intersect: air.intersection(piece.solid)
            }
        }
    }

    /// The room the pieces make, with the given materials and their labels. Nil if they make no room.
    public func room(materials: [SurfaceMaterial], labels: [String]? = nil) -> RoomMesh? {
        guard let solid else { return nil }
        let usesMaterial = allSatisfy { piece in
            let indices: [Int] =
                switch piece.shape {
                case .box(_, _, let materials): materials
                case .extrusion(_, _, _, _, let sides, let ends): sides + ends
                }
            return indices.allSatisfy { materials.indices.contains($0) }
        }
        guard usesMaterial else { return nil }
        var mesh = solid.room(materials: materials)
        guard !mesh.faces.isEmpty else { return nil }
        mesh.labels = labels
        return mesh
    }

    /// The pieces with the plane `normal · p = offset` moved by `shift`, as pushing a surface of the room
    /// on that plane moves it. A box's face on the plane moves with it, stretching the box, but a piece
    /// cut out of the air whose opposite face rests on nothing, such as seating on a floor or a balcony
    /// against a wall, moves whole. An extrusion's end on the plane, or its sides on the plane, move,
    /// stretching it. A box cut out of the air that rests on a piece moving whole, such as seating on a
    /// balcony, moves with it. Nil if no piece has a face on the plane, or if a piece would turn inside
    /// out.
    public func pushing(plane normal: SIMD3<Double>, offset: Double, by shift: SIMD3<Double>) -> [HallPiece]?
    {
        let tolerance = 1e-6
        func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < tolerance }
        // The axis a plane lies across, if it is square to one.
        let across = (0..<3).first { abs(abs(normal[$0]) - 1) < tolerance }
        var result = self
        var moved = false
        var touched: Set<Int> = []
        var whole: Set<Int> = []
        for index in indices {
            let piece = self[index]
            switch piece.shape {
            case .box(var low, var high, let materials):
                guard let k = across else { continue }
                let c = offset / normal[k]
                let touchesLow = near(low[k], c)
                guard touchesLow || near(high[k], c) else { continue }
                moved = true
                touched.insert(index)
                let opposite = touchesLow ? high[k] : low[k]
                let rests = indices.contains { other in
                    other != index && self[other].hasFace(across: k, at: opposite, overlapping: piece.bounds)
                }
                if piece.operation == .cut && !rests {
                    result[index] = piece.translated(by: shift)
                    whole.insert(index)
                    continue
                }
                if touchesLow { low[k] += shift[k] } else { high[k] += shift[k] }
                guard low[k] < high[k] else { return nil }
                result[index].shape = .box(low: low, high: high, materials: materials)
            case .extrusion(var points, let axis, var from, var to, let sides, let ends):
                if across == axis {
                    let c = offset / normal[axis]
                    if near(from, c) {
                        from += shift[axis]
                    } else if near(to, c) {
                        to += shift[axis]
                    } else {
                        continue
                    }
                    guard from < to else { return nil }
                } else if abs(normal[axis]) < tolerance {
                    let (a, b) = HallPiece.planeAxes(axis)
                    let n = SIMD2(normal[a], normal[b])
                    let on = points.map { near(simd_dot(n, $0), offset) }
                    // Points on a side that lies on the plane, not those that merely touch it.
                    let moving = points.indices.filter { i in
                        on[i] && (on[(i + 1) % points.count] || on[(i + points.count - 1) % points.count])
                    }
                    guard !moving.isEmpty else { continue }
                    let before = Self.signedArea(points)
                    for i in moving { points[i] += SIMD2(shift[a], shift[b]) }
                    let after = Self.signedArea(points)
                    guard abs(after) > tolerance, (before > 0) == (after > 0) else { return nil }
                } else {
                    continue
                }
                moved = true
                touched.insert(index)
                result[index].shape = .extrusion(
                    points: points, axis: axis, from: from, to: to, sides: sides, ends: ends)
            }
        }
        // Boxes cut out of the air that rest on a piece moving whole go with it.
        var resting = true
        while resting {
            resting = false
            for index in indices where !touched.contains(index) && self[index].operation == .cut {
                guard case .box(let low, let high, _) = self[index].shape else { continue }
                let bounds = self[index].bounds
                let carried = whole.contains { other in
                    (0..<3).contains { k in
                        [low[k], high[k]].contains {
                            self[other].hasFace(across: k, at: $0, overlapping: bounds)
                        }
                    }
                }
                guard carried else { continue }
                result[index] = self[index].translated(by: shift)
                touched.insert(index)
                whole.insert(index)
                resting = true
            }
        }
        return moved ? result : nil
    }

    static func signedArea(_ points: [SIMD2<Double>]) -> Double {
        points.indices.reduce(0) { total, i in
            let (p, q) = (points[i], points[(i + 1) % points.count])
            return total + (p.x * q.y - q.x * p.y) / 2
        }
    }
}

extension HallPiece {
    /// Whether the piece has a face square to axis `k` at `c` that overlaps `bounds` across the other
    /// two axes.
    func hasFace(across k: Int, at c: Double, overlapping bounds: (min: SIMD3<Double>, max: SIMD3<Double>))
        -> Bool
    {
        let tolerance = 1e-6
        let own = self.bounds
        let overlaps = (0..<3).allSatisfy { axis in
            axis == k
                || (own.min[axis] < bounds.max[axis] + tolerance
                    && bounds.min[axis] < own.max[axis] + tolerance)
        }
        guard overlaps else { return false }
        switch shape {
        case .box(let low, let high, _):
            return abs(low[k] - c) < tolerance || abs(high[k] - c) < tolerance
        case .extrusion(let points, let axis, let from, let to, _, _):
            if axis == k { return abs(from - c) < tolerance || abs(to - c) < tolerance }
            let (a, b) = Self.planeAxes(axis)
            let along = k == a ? 0 : k == b ? 1 : -1
            guard along >= 0 else { return false }
            return points.indices.contains { i in
                abs(points[i][along] - c) < tolerance
                    && abs(points[(i + 1) % points.count][along] - c) < tolerance
            }
        }
    }
}
