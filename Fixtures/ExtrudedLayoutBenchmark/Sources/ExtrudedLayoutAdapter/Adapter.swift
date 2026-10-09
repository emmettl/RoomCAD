import Foundation
import simd

@testable import AcousticCore

struct Specification: Codable {
    let id: String, corners: [[Double]], lengths: [Double], dimensions: [Int], impedances: [Double?],
        speed: Double
}
struct Cases: Decodable { let schemaVersion: Int, cases: [Specification] }
struct Layout: Encodable {
    let inside: [UInt8], faces: [Float], selectedFaces: [Int], spacing: [Double], dt: Double
}
struct Record: Encodable {
    let schemaVersion = 1
    let specification: Specification, representation: String, layout: Layout, materialImpedances: [Double?]
}
func argument(_ name: String) throws -> String {
    guard let i = CommandLine.arguments.firstIndex(of: name), i + 1 < CommandLine.arguments.count else {
        throw NSError(domain: "Missing argument", code: 1)
    }
    return CommandLine.arguments[i + 1]
}
let specifications = try JSONDecoder().decode(
    Cases.self, from: Data(contentsOf: URL(fileURLWithPath: try argument("--cases"))))
let output = URL(fileURLWithPath: try argument("--output"))
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
for c in specifications.cases {
    let materials = c.impedances.map { xi -> SurfaceMaterial in
        guard let xi else { return .rigid }
        let alpha = 8 / xi * (1 + 1 / (1 + xi) - 2 / xi * log(1 + xi))
        return .uniform(
            alpha, name: "Independent xi=\(xi) extrusion control",
            reference: "Independently authored statistical absorption integral")
    }
    let plan = FloorPlan(corners: c.corners.map { SIMD2<Double>($0) }, walls: Array(materials.prefix(4)))
    let size = SIMD3<Double>(c.lengths)
    let mesh = RoomMesh.extruding(plan, height: size.z, floor: materials[4], ceiling: materials[5])
    let atmosphere = Atmosphere(
        temperatureCelsius: pow(c.speed / 331.3, 2) * 273.15 - 273.15, relativeHumidity: 0,
        pressureKilopascals: 101.325)
    for representation in ["plan", "mesh"] {
        var room = ShoeboxRoom(size: size, material: .rigid)
        if representation == "plan" { room.plan = plan } else { room.mesh = mesh }
        let solver = WaveSolver(
            room: room, sampleRate: 768000,
            topFrequency: atmosphere.soundSpeed * Double(c.dimensions[0]) / (10 * size.x) * (1 - 1e-9),
            atmosphere: atmosphere)
        guard solver.cells == SIMD3<Int>(c.dimensions) else {
            throw NSError(domain: "Unexpected dimensions", code: 2)
        }
        let layout = solver.gridLayout(source: [0.1, 0.18, size.z / 2], receivers: [])
        let impedance = materials.map { solver.impedance(material: $0) }
        for (actual, expected) in zip(impedance, c.impedances) {
            if let expected {
                guard actual.isFinite, abs(actual / expected - 1) < 1e-6 else {
                    throw NSError(domain: "Unexpected impedance", code: 3)
                }
            } else {
                guard actual.isInfinite else { throw NSError(domain: "Expected rigid wall", code: 4) }
            }
        }
        let nx = solver.cells.x
        let ny = solver.cells.y
        let count = layout.count
        var selected = [Int](repeating: -1, count: 6 * count)
        let geometry = MeshGeometry.of(mesh)
        for index in layout.faces.indices where layout.faces[index] >= 0 {
            let side = index / count
            let cell = index % count
            let axis = side / 2
            var point =
                (SIMD3<Double>(Double(cell % nx), Double((cell / nx) % ny), Double(cell / (nx * ny))) + 0.5)
                * solver.spacing
            point[axis] += (side % 2 == 0 ? -0.5 : 0.5) * solver.spacing[axis]
            // Diagnostic repeats the current source selection only; the shared oracle uses segment exits.
            selected[index] =
                representation == "mesh"
                ? geometry.nearestFace(point) : (axis == 2 ? side : plan.nearestWall([point.x, point.y]))
        }
        let record = Record(
            specification: c, representation: representation,
            layout: Layout(
                inside: layout.inside, faces: layout.faces, selectedFaces: selected,
                spacing: [solver.spacing.x, solver.spacing.y, solver.spacing.z], dt: solver.timeStep),
            materialImpedances: impedance.map { $0.isFinite ? $0 : nil })
        try encoder.encode(record).write(
            to: output.appendingPathComponent(c.id + "-" + representation + ".layout.json"))
    }
}
print("Retained \(specifications.cases.count*2) complete actual-source geometry layouts")
