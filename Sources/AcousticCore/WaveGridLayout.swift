import Foundation
import simd

extension WaveSolver {
    /// Everything the GPU needs about the grid, built from the same rules as the CPU solvers.
    struct GridLayout {
        var count: Int
        /// One flag per cell: whether it is simulated.
        var inside: [UInt8]
        /// Six faces per cell, in the order -x, +x, -y, +y, -z, +z, each laid out over all cells; -1 marks a
        /// face to a neighbour, otherwise the wall term β = c dt a / (2 ξ d), where a is the
        /// local surface-area weight (one for an axis-aligned wall).
        var faces: [Float]
        var sourceCells: [Int]
        /// Injection weights scaled by c² dt / V.
        var sourceWeights: [Float]
        /// Eight cells and weights per receiver.
        var receiverCells: [Int]
        var receiverWeights: [Float]
        var velocityCells: [Int]
        var axes: [Float]
    }

    func gridLayout(source: SIMD3<Double>, receivers: [(position: SIMD3<Double>, microphone: Microphone)])
        -> GridLayout
    {
        let nx = cells.x
        let ny = cells.y
        let nz = cells.z
        let plane = nx * ny
        let count = plane * nz
        let c = atmosphere.soundSpeed
        let dt = timeStep
        let centre = { (i: Int, j: Int, k: Int) in (SIMD3(Double(i), Double(j), Double(k)) + 0.5) * spacing }
        // Cells whose centres lie in the room: every cell of a box, whole columns of a plan, and for a
        // mesh the stretches of each column between where a vertical line enters and leaves it.
        var inside = [UInt8](repeating: 1, count: count)
        let mesh = room.mesh.map(MeshGeometry.of)
        if let plan = room.plan {
            for j in 0..<ny {
                for i in 0..<nx where !plan.contains([centre(i, j, 0).x, centre(i, j, 0).y]) {
                    for k in 0..<nz { inside[i + nx * (j + ny * k)] = 0 }
                }
            }
        } else if let mesh {
            for j in 0..<ny {
                for i in 0..<nx {
                    let point = centre(i, j, 0)
                    let crossings = mesh.verticalCrossings(x: point.x, y: point.y)
                    for k in 0..<nz {
                        let z = centre(i, j, k).z
                        let below = crossings.filter { $0 < z }.count
                        inside[i + nx * (j + ny * k)] = below % 2 == 1 ? 1 : 0
                    }
                }
            }
        }
        let active = { (i: Int, j: Int, k: Int) in
            i >= 0 && i < nx && j >= 0 && j < ny && k >= 0 && k < nz && inside[i + nx * (j + ny * k)] == 1
        }
        func beta(_ xi: Double, _ depth: Double) -> Float {
            let value = c * dt / (2 * xi * depth)
            return value.isFinite ? Float(value) : 0
        }
        let surfaceImpedance = Dictionary(uniqueKeysWithValues: Surface.allCases.map { ($0, impedance($0)) })
        let wallImpedance = room.plan?.walls.map { impedance(material: $0) } ?? []
        // A planar surface contributes |n_x| + |n_y| + |n_z| times its physical area to the
        // Cartesian staircase. Share its admittance over those grid faces using the local
        // unit normal. This changes wall work, not cell volumes or interior fluxes.
        func areaWeight(_ normal: SIMD3<Double>) -> Double {
            1 / (abs(normal.x) + abs(normal.y) + abs(normal.z))
        }
        // Air in an open face, otherwise the face's material.
        let faceImpedance = room.mesh.map { mesh in
            mesh.faces.indices.map {
                mesh.faces[$0].open ? 1 : impedance(material: mesh.materials[mesh.faces[$0].material])
            }
        }
        // A box face: the surface's impedance, or air's in an opening.
        func boxFace(_ surface: Surface, _ point: SIMD3<Double>) -> Float {
            let (a, b) = surface.planeAxes
            let open = openings.contains {
                $0.wall == nil && $0.surface == surface && $0.contains([point[a], point[b]])
            }
            return beta(open ? 1 : surfaceImpedance[surface]!, spacing[surface.normalAxis])
        }
        // A plan's wall face: the nearest wall's impedance, or air's in an opening.
        func planFace(_ point: SIMD2<Double>, height: Double, depth: Double) -> Float {
            let plan = room.plan!
            let wall = plan.nearestWall(point)
            let start = plan.start(wall)
            let along = simd_dot(point - start, simd_normalize(plan.end(wall) - start))
            let open = openings.contains { $0.wall == wall && $0.contains([along, height]) }
            let normal = plan.inwardNormal(wall)
            return beta(open ? 1 : wallImpedance[wall], depth)
                * Float(areaWeight([normal.x, normal.y, 0]))
        }
        var faces = [Float](repeating: -1, count: 6 * count)
        let steps: [(SIMD3<Int>, Int)] = [
            ([-1, 0, 0], 0), ([1, 0, 0], 0), ([0, -1, 0], 1), ([0, 1, 0], 1), ([0, 0, -1], 2),
            ([0, 0, 1], 2),
        ]
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx where inside[i + nx * (j + ny * k)] == 1 {
                    let at = i + nx * (j + ny * k)
                    let point = centre(i, j, k)
                    for (side, (step, axis)) in steps.enumerated()
                    where !active(i + step.x, j + step.y, k + step.z) {
                        let face = point + SIMD3<Double>(step) * spacing / 2
                        if let mesh, let faceImpedance {
                            // Select the wall this centre-to-neighbour segment crosses. A thin
                            // room's cap can be nearer to the midpoint without bounding this link.
                            // Retain the legacy fallback for unresolved edge/degenerate queries.
                            let boundary =
                                mesh.nearestHit(
                                    origin: point, direction: SIMD3<Double>(step) * spacing,
                                    limit: 1 + 1e-9)?.face ?? mesh.nearestFace(face)
                            // An extrusion keeps its floor-plan area quadrature: sample the
                            // closest in-plane side normal, excluding caps. Material ownership
                            // still comes from the crossed face. General meshes use its normal.
                            let measure: Int
                            if axis < 2, let sides = mesh.extrusionSideFaces {
                                measure = mesh.nearestFace(face, among: sides)
                            } else {
                                measure = boundary
                            }
                            faces[side * count + at] =
                                beta(faceImpedance[boundary], spacing[axis])
                                * Float(areaWeight(mesh.faces[measure].normal))
                        } else if room.plan != nil, axis < 2 {
                            faces[side * count + at] = planFace(
                                [face.x, face.y], height: face.z, depth: spacing[axis])
                        } else {
                            let surface: Surface = [.west, .east, .south, .north, .floor, .ceiling][side]
                            faces[side * count + at] = boxFace(surface, point)
                        }
                    }
                }
            }
        }
        // Trilinear weights over simulated cells, renormalized, padded to eight.
        func weights(_ point: SIMD3<Double>) -> [(Int, Float)] {
            let g = point / spacing - 0.5
            let base = SIMD3<Int>(
                min(max(Int(g.x.rounded(.down)), 0), nx - 2), min(max(Int(g.y.rounded(.down)), 0), ny - 2),
                min(max(Int(g.z.rounded(.down)), 0), nz - 2))
            let f = simd_clamp(g - SIMD3<Double>(base), SIMD3(repeating: 0), SIMD3(repeating: 1))
            var result: [(Int, Double)] = []
            for corner in 0..<8 {
                let o = SIMD3<Int>(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1)
                let cell = (base.x + o.x) + nx * ((base.y + o.y) + ny * (base.z + o.z))
                let w = (o.x == 1 ? f.x : 1 - f.x) * (o.y == 1 ? f.y : 1 - f.y) * (o.z == 1 ? f.z : 1 - f.z)
                result.append((cell, inside[cell] == 1 ? w : 0))
            }
            let total = result.reduce(0) { $0 + $1.1 }
            guard total > 0 else {
                // Outside every simulated cell round it: the nearest simulated cell, padded to eight.
                let nearest =
                    (0..<count).filter { inside[$0] == 1 }.min {
                        simd_distance_squared(centre($0 % nx, ($0 / nx) % ny, $0 / plane), point)
                            < simd_distance_squared(centre($1 % nx, ($1 / nx) % ny, $1 / plane), point)
                    } ?? 0
                return [(nearest, 1)] + Array(repeating: (nearest, 0), count: 7)
            }
            return result.map { ($0.0, Float($0.1 / total)) }
        }
        let injection = Float(c * c * dt / (spacing.x * spacing.y * spacing.z))
        let sourceWeights = weights(source)
        let receiverWeights = receivers.map { weights($0.position) }
        return GridLayout(
            count: count, inside: inside, faces: faces, sourceCells: sourceWeights.map(\.0),
            sourceWeights: sourceWeights.map { $0.1 * injection },
            receiverCells: receiverWeights.flatMap { $0.map(\.0) },
            receiverWeights: receiverWeights.flatMap { $0.map(\.1) },
            velocityCells: receivers.map { receiver in
                let cell = velocityProbeCell(receiver.position)
                return cell.x + nx * (cell.y + ny * cell.z)
            },
            axes: receivers.flatMap {
                [Float($0.microphone.axis.x), Float($0.microphone.axis.y), Float($0.microphone.axis.z)]
            })
    }
}
