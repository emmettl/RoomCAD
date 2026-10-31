import Foundation

@testable import AcousticCore

/// Runs within the four-file original numerical module; no application sources are linked.
enum MeasurementDomainWitness {
    struct Record: Encodable {
        let name: String
        let count: Int
        let compensated: Bool
        let energyFile: String
        let parameterBits: [String: String?]
        let defaultJSONAccepted: Bool
        let actualNoiseCut: Int?
        let actualNoiseTailBits: String?
        let reconstructedCurveFile: String
    }
    static func bits(_ value: Double) -> String { String(format: "%016llx", value.bitPattern) }
    static func write(_ values: [Double], to url: URL) throws {
        var data = Data(capacity: values.count * 8)
        for value in values {
            var word = value.bitPattern.littleEndian
            withUnsafeBytes(of: &word) { data.append(contentsOf: $0) }
        }
        try data.write(to: url)
    }
    public static func run(_ directory: String) throws {
        let root = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var late = Array(repeating: 0.0, count: 4801)
        late[0] = 1
        late[4000] = 1e-20
        var cases: [(String, [Double])] = [
            ("empty", []), ("silent", Array(repeating: 0, count: 2400)),
            ("constant-2400", Array(repeating: 1, count: 2400)),
            ("constant-4800", Array(repeating: 1, count: 4800)),
            ("constant-9600", Array(repeating: 1, count: 9600)), ("positive-late", late),
        ]
        for duration in [0.12, 3.0] {
            let energy = (0..<Int(duration * 48_000)).map { exp(-6 * log(10) * Double($0) / 48_000 / 1.2) }
            cases.append((duration < 1 ? "short-exponential" : "long-exponential", energy))
        }
        var records: [Record] = []
        for (name, energy) in cases {
            let energyFile = name + ".f64le"
            try write(energy, to: root.appendingPathComponent(energyFile))
            for compensated in [false, true] {
                let parameters = RoomParameters.measure(
                    energy: energy, sampleRate: 48_000, noiseCompensated: compensated)
                let cut = compensated ? RoomParameters.noiseCut(energy, sampleRate: 48_000) : nil
                let end = cut?.index ?? energy.count
                var curve = Array(repeating: 0.0, count: end)
                var sum = cut?.tail ?? 0
                for index in stride(from: end - 1, through: 0, by: -1) {
                    sum += energy[index]
                    curve[index] = sum
                }
                let reconstructed = curve.map { 10 * log10(max($0, .leastNonzeroMagnitude) / sum) }
                let curveFile = name + (compensated ? "-corrected" : "-raw") + "-reconstructed-curve.f64le"
                try write(reconstructed, to: root.appendingPathComponent(curveFile))
                records.append(
                    Record(
                        name: name, count: energy.count, compensated: compensated,
                        energyFile: energyFile,
                        parameterBits: [
                            "edt": parameters.edt.map(bits), "t20": parameters.t20.map(bits),
                            "t30": parameters.t30.map(bits),
                            "c50": bits(parameters.c50), "c80": bits(parameters.c80),
                            "d50": bits(parameters.d50),
                            "centreTime": bits(parameters.centreTime),
                        ],
                        defaultJSONAccepted: (try? JSONEncoder().encode(parameters)) != nil,
                        actualNoiseCut: cut?.index, actualNoiseTailBits: cut.map { bits($0.tail) },
                        reconstructedCurveFile: curveFile))
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: root.appendingPathComponent("records.json"))
    }
}
