import Foundation
import simd

@testable import AcousticCore

// Original c47fdc889ef294571fa5683963e5892afe5e38ab masked CPU method, verbatim.
extension WaveSolver {
    /// The same scheme for a room with a floor plan or a mesh: cells whose centres lie inside the room are
    /// simulated, and every face between a simulated cell and one that is not is a wall with the
    /// impedance of the nearest wall, plan wall or mesh face (or air, in an opening or open face): a
    /// staircase approximation of walls that are not aligned with the grid. It shares its layout with the
    /// GPU solver.
    func simulateMasked(
        source: SIMD3<Double>, receivers: [(position: SIMD3<Double>, microphone: Microphone)], steps: Int,
        stop: @Sendable () -> Bool
    ) -> [[Double]]? {
        let nx = cells.x
        let ny = cells.y
        let nz = cells.z
        let count = nx * ny * nz
        let plane = nx * ny
        let c = atmosphere.soundSpeed
        let dt = timeStep
        let index = { (i: Int, j: Int, k: Int) in i + nx * (j + ny * k) }
        let layout = gridLayout(source: source, receivers: receivers)
        let inside = layout.inside.map { $0 == 1 }
        let faces = (0..<6).map { Array(layout.faces[($0 * count)..<(($0 + 1) * count)]) }

        let p = UnsafeMutablePointer<Float>.allocate(capacity: count)
        let ux = UnsafeMutablePointer<Float>.allocate(capacity: count)
        let uy = UnsafeMutablePointer<Float>.allocate(capacity: count)
        let uz = UnsafeMutablePointer<Float>.allocate(capacity: count)
        for field in [p, ux, uy, uz] { field.initialize(repeating: 0, count: count) }
        defer { for field in [p, ux, uy, uz] { field.deallocate() } }

        // Trilinear weights over simulated cells, from the layout; its source weights include c² dt / V.
        let sourceWeights = Array(zip(layout.sourceCells, layout.sourceWeights))
        let receiverWeights = receivers.indices.map { r in
            Array(
                zip(
                    layout.receiverCells[(8 * r)..<(8 * r + 8)], layout.receiverWeights[(8 * r)..<(8 * r + 8)]
                ))
        }
        let receiverCells = receivers.map { velocityProbeCell($0.position) }
        var pressure = Array(repeating: [Double](repeating: 0, count: steps), count: receivers.count)
        var velocity = Array(repeating: [Double](repeating: 0, count: steps + 1), count: receivers.count)
        let slabs = count < 4_096 ? 1 : min(nz, 16)
        func forEachSlab(_ body: (Int) -> Void) {
            if slabs == 1 {
                body(0)
            } else {
                // Each slab writes only its own planes of the field buffers.
                nonisolated(unsafe) let body = body
                DispatchQueue.concurrentPerform(iterations: slabs) { body($0) }
            }
        }
        let kx = Float(dt / spacing.x)
        let ky = Float(dt / spacing.y)
        let kz = Float(dt / spacing.z)
        let bx = Float(c * c * dt / spacing.x)
        let by = Float(c * c * dt / spacing.y)
        let bz = Float(c * c * dt / spacing.z)
        let (west, east, south, north, floor, ceiling) = (
            faces[0], faces[1], faces[2], faces[3], faces[4], faces[5]
        )

        for n in 0..<steps {
            if n % 64 == 0, stop() { return nil }
            // Velocity on faces between two simulated cells; others stay zero and are walls.
            forEachSlab { slab in
                for k in (slab * nz / slabs)..<((slab + 1) * nz / slabs) {
                    for j in 0..<ny {
                        let row = nx * (j + ny * k)
                        for i in 0..<nx where inside[row + i] {
                            let at = row + i
                            if i < nx - 1, inside[at + 1] { ux[at] -= kx * (p[at + 1] - p[at]) }
                            if j < ny - 1, inside[at + nx] { uy[at] -= ky * (p[at + nx] - p[at]) }
                            if k < nz - 1, inside[at + plane] { uz[at] -= kz * (p[at + plane] - p[at]) }
                        }
                    }
                }
            }
            forEachSlab { slab in
                for k in (slab * nz / slabs)..<((slab + 1) * nz / slabs) {
                    for j in 0..<ny {
                        let row = nx * (j + ny * k)
                        for i in 0..<nx where inside[row + i] {
                            let at = row + i
                            var divergence: Float = 0
                            var wall: Float = 0
                            if west[at] < 0 { divergence -= bx * ux[at - 1] } else { wall += west[at] }
                            if east[at] < 0 { divergence += bx * ux[at] } else { wall += east[at] }
                            if south[at] < 0 { divergence -= by * uy[at - nx] } else { wall += south[at] }
                            if north[at] < 0 { divergence += by * uy[at] } else { wall += north[at] }
                            if floor[at] < 0 { divergence -= bz * uz[at - plane] } else { wall += floor[at] }
                            if ceiling[at] < 0 { divergence += bz * uz[at] } else { wall += ceiling[at] }
                            p[at] = ((1 - wall) * p[at] - divergence) / (1 + wall)
                        }
                    }
                }
            }
            let q = pulse((Double(n) + 0.5) * dt)
            for (cell, w) in sourceWeights { p[cell] += Float(q) * w }
            for (r, receiver) in receivers.enumerated() {
                var value = 0.0
                for (cell, w) in receiverWeights[r] { value += Double(p[cell]) * Double(w) }
                pressure[r][n] = value
                if !receiver.microphone.isOmni {
                    let cell = receiverCells[r]
                    let at = index(cell.x, cell.y, cell.z)
                    let u = SIMD3<Double>(
                        Double(ux[at - 1] + ux[at]) / 2, Double(uy[at - nx] + uy[at]) / 2,
                        Double(uz[at - plane] + uz[at]) / 2)
                    velocity[r][n + 1] = simd_dot(u, receiver.microphone.axis)
                }
            }
        }
        return receivers.indices.map { r in
            let microphone = receivers[r].microphone
            guard !microphone.isOmni else { return pressure[r] }
            let a = microphone.pattern.omniShare
            return (0..<steps).map { n in
                let v =
                    n + 2 <= steps
                    ? (velocity[r][n + 1] + velocity[r][min(n + 2, steps)]) / 2 : velocity[r][n + 1]
                return a * pressure[r][n] - (1 - a) * c * v
            }
        }
    }
}

/// Verification-only original control; excluded from application products.
struct OriginalMaskedCPUSimulation: MaskedCPUSimulation {
    func simulate(
        _ solver: WaveSolver, source: SIMD3<Double>,
        receivers: [(position: SIMD3<Double>, microphone: Microphone)], steps: Int,
        stop: @Sendable () -> Bool
    ) -> [[Double]]? {
        solver.simulateMasked(source: source, receivers: receivers, steps: steps, stop: stop)
    }
}

extension WaveSolver {
    /// Select the verification-only original loop with the current app-owned layout.
    func usingOriginalMaskedCPU() -> Self {
        var result = self
        result.maskedCPUBackend = OriginalMaskedCPUSimulation()
        return result
    }
}
