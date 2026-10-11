import Foundation
import ImpulseResponseKit

extension AbsorptionCalibration {
    public enum ValidationFailure: String, Error, Equatable, Sendable {
        case invalidTargetDimensions, invalidTarget, invalidTolerance, invalidIterations
    }

    public enum TargetMeasurement: Equatable, Sendable {
        case notTargeted
        case unavailable
        case matched(relativeError: Double)
        case outsideTolerance(relativeError: Double)

        /// Assessment only; callers obtain validated outcomes through `fitValidated`.
        static func assess(time: Double?, target: Double?, tolerance: Double) -> Self {
            guard let goal = target else { return .notTargeted }
            guard let time, time.isFinite, time > 0 else { return .unavailable }
            let error = abs(time / goal - 1)
            return error <= tolerance
                ? .matched(relativeError: error) : .outsideTolerance(relativeError: error)
        }
    }

    /// Historical selection and an independent measurement of the actual returned room.
    /// A verified measurement is numerical evidence under the supplied simulation, not
    /// empirical accuracy or a guarantee that optimization found a matching room.
    public struct ValidatedOutcome: Sendable {
        public let room: ShoeboxRoom
        public let steps: [Step]
        public let selectedBest: Step
        /// Nil only when no targets were supplied and no simulation was necessary.
        public let verification: Step?
        public let targets: [Double?]
        public let tolerance: Double
        public let measurements: [TargetMeasurement]

        public var targetedBandCount: Int { targets.compactMap { $0 }.count }
        public var measuredBandCount: Int {
            measurements.filter {
                switch $0 {
                case .matched, .outsideTolerance: true
                case .notTargeted, .unavailable: false
                }
            }.count
        }
        public var matchedBandCount: Int {
            measurements.filter { if case .matched = $0 { true } else { false } }.count
        }
        public var allTargetsMatched: Bool {
            targetedBandCount > 0 && matchedBandCount == targetedBandCount
        }
        public var simulationCount: Int { steps.count + (verification == nil ? 0 : 1) }

        fileprivate init(
            room: ShoeboxRoom, steps: [Step], selectedBest: Step, verification: Step?,
            targets: [Double?], tolerance: Double, measurements: [TargetMeasurement]
        ) {
            self.room = room
            self.steps = steps
            self.selectedBest = selectedBest
            self.verification = verification
            self.targets = targets
            self.tolerance = tolerance
            self.measurements = measurements
        }
    }

    /// Runs the unchanged legacy search, then measures its assembled selected room once.
    /// `iterations` counts allowed search updates: at most iterations+1 search simulations
    /// and one verification simulation. No-target input returns unchanged without simulation.
    /// The verification neither changes factors nor fills unavailable values from history.
    public static func fitValidated(
        _ settings: RoomResponseSettings, to target: [Double?], tolerance: Double = 0.02,
        iterations: Int = 5,
        simulate: (RoomResponseSettings) throws -> [[Float]] = {
            try RoomResponseGenerator.generate($0).response.channels
        }
    ) throws -> ValidatedOutcome {
        guard target.count == OctaveBands.count else { throw ValidationFailure.invalidTargetDimensions }
        guard target.allSatisfy({ $0 == nil || ($0!.isFinite && $0! > 0) }) else {
            throw ValidationFailure.invalidTarget
        }
        guard tolerance.isFinite, tolerance >= 0 else { throw ValidationFailure.invalidTolerance }
        guard iterations >= 0 else { throw ValidationFailure.invalidIterations }
        if target.allSatisfy({ $0 == nil }) {
            let unchanged = Step(
                reverberationTime: Array(repeating: nil, count: OctaveBands.count),
                factors: Array(repeating: 1, count: OctaveBands.count))
            return ValidatedOutcome(
                room: settings.room, steps: [], selectedBest: unchanged, verification: nil,
                targets: target, tolerance: tolerance,
                measurements: Array(repeating: .notTargeted, count: OctaveBands.count))
        }
        let selected = try fit(
            settings, to: target, tolerance: tolerance, iterations: iterations, simulate: simulate)
        var finalSettings = settings
        finalSettings.room = selected.room
        let channels = try simulate(finalSettings)
        // Same filtering, negative-slope T30 extraction and all-receiver mean as legacy fit.
        // Keep a separate actual final response; historical best times are never substituted.
        let times = OctaveBands.centres.indices.map { band -> Double? in
            let measured = channels.compactMap {
                DecayAnalysis.reverberationTime(
                    DecayAnalysis.measuredOctaveBand($0, sampleRate: settings.sampleRate, band: band),
                    sampleRate: settings.sampleRate)
            }
            return measured.count == channels.count && !measured.isEmpty
                ? measured.reduce(0, +) / Double(measured.count) : nil
        }
        let verification = Step(reverberationTime: times, factors: selected.best.factors)
        let measurements = target.indices.map { band -> TargetMeasurement in
            TargetMeasurement.assess(time: times[band], target: target[band], tolerance: tolerance)
        }
        return ValidatedOutcome(
            room: selected.room, steps: selected.steps, selectedBest: selected.best,
            verification: verification, targets: target, tolerance: tolerance,
            measurements: measurements)
    }
}
