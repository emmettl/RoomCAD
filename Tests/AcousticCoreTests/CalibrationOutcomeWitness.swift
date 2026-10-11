import Foundation

@testable import AcousticCore

/// Optional complete native callback evidence, written only to an explicit CI/study directory.
enum CalibrationOutcomeWitness {
    struct Step: Codable {
        let factors: [Double]
        let times: [Double?]
        init(_ step: AbsorptionCalibration.Step) {
            factors = step.factors
            times = step.reverberationTime
        }
    }
    struct Outcome: Codable {
        let settings: RoomResponseSettings
        let targets: [Double?]
        let tolerance: Double
        let iterations: Int
        let trials: [RoomResponseSettings]
        let responseFiles: [[String]]
        let responseSampleCounts: [[Int]]
        let steps: [Step]
        let selected: Step
        let verification: Step?
        let room: ShoeboxRoom
        let measurements: [String]
        let errors: [Double?]
        let simulationCount: Int
        let allTargetsMatched: Bool
    }

    static func write(
        name: String, settings: RoomResponseSettings, targets: [Double?], tolerance: Double,
        iterations: Int, trials: [RoomResponseSettings], responses: [[[Float]]],
        result: AbsorptionCalibration.ValidatedOutcome
    ) throws {
        guard let directory = ProcessInfo.processInfo.environment["ROOMCAD_CALIBRATION_EVIDENCE_DIR"] else {
            return
        }
        let root = URL(fileURLWithPath: directory).appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var files: [[String]] = []
        for (trial, channels) in responses.enumerated() {
            var names: [String] = []
            for (channel, samples) in channels.enumerated() {
                let name = "trial-\(trial)-channel-\(channel).f32le"
                var data = Data(capacity: samples.count * 4)
                for sample in samples {
                    var bits = sample.bitPattern.littleEndian
                    withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
                }
                try data.write(to: root.appendingPathComponent(name))
                names.append(name)
            }
            files.append(names)
        }
        let assessments = result.measurements.map { value -> (String, Double?) in
            switch value {
            case .notTargeted: ("notTargeted", nil)
            case .unavailable: ("unavailable", nil)
            case .matched(let error): ("matched", error)
            case .outsideTolerance(let error): ("outsideTolerance", error)
            }
        }
        let outcome = Outcome(
            settings: settings, targets: targets, tolerance: tolerance, iterations: iterations,
            trials: trials, responseFiles: files, responseSampleCounts: responses.map { $0.map(\.count) },
            steps: result.steps.map(Step.init), selected: Step(result.selectedBest),
            verification: result.verification.map(Step.init), room: result.room,
            measurements: assessments.map(\.0), errors: assessments.map(\.1),
            simulationCount: result.simulationCount, allTargetsMatched: result.allTargetsMatched)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(outcome).write(to: root.appendingPathComponent("outcome.json"))
    }
}
