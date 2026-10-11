import Foundation
import Testing

@testable import AcousticCore

@Suite("Verified calibration outcomes")
struct ValidatedAbsorptionCalibrationTests {
    @Test("No targets is not convergence and performs no simulation")
    func noTargets() throws {
        let result = try AbsorptionCalibration.fitValidated(
            CalibrationOutcomeAuditTests.settings, to: Array(repeating: nil, count: 8)
        ) { _ in
            Issue.record("No target simulation")
            return []
        }
        #expect(result.steps.isEmpty)
        #expect(result.verification == nil)
        #expect(result.targetedBandCount == 0)
        #expect(result.simulationCount == 0)
        #expect(!result.allTargetsMatched)
    }

    @Test("Unavailable final measurements never become historic matches")
    func unavailable() throws {
        var calls = 0
        let result = try AbsorptionCalibration.fitValidated(
            CalibrationOutcomeAuditTests.settings, to: [nil, nil, nil, 1, nil, nil, nil, nil]
        ) { _ in
            calls += 1
            return [[Float](repeating: 0, count: 2048)]
        }
        #expect(calls == 2)
        #expect(result.steps.count == 1)
        #expect(result.simulationCount == calls)
        #expect(result.verification?.factors == result.selectedBest.factors)
        #expect(result.measurements[3] == .unavailable)
        #expect(result.targetedBandCount == 1)
        #expect(result.measuredBandCount == 0)
        #expect(!result.allTargetsMatched)
    }

    @Test("Invalid input fails before any simulation")
    func invalidInput() {
        let settings = CalibrationOutcomeAuditTests.settings
        let forbidden: (RoomResponseSettings) throws -> [[Float]] = { _ in
            Issue.record("Invalid input reached simulation")
            return []
        }
        #expect(throws: AbsorptionCalibration.ValidationFailure.invalidTargetDimensions) {
            try AbsorptionCalibration.fitValidated(settings, to: [], simulate: forbidden)
        }
        for goal in [0, -1, Double.infinity, Double.nan] {
            #expect(throws: AbsorptionCalibration.ValidationFailure.invalidTarget) {
                try AbsorptionCalibration.fitValidated(
                    settings, to: [goal, nil, nil, nil, nil, nil, nil, nil], simulate: forbidden)
            }
        }
        for tolerance in [-1, Double.infinity, Double.nan] {
            #expect(throws: AbsorptionCalibration.ValidationFailure.invalidTolerance) {
                try AbsorptionCalibration.fitValidated(
                    settings, to: Array(repeating: nil, count: 8), tolerance: tolerance, simulate: forbidden)
            }
        }
        #expect(throws: AbsorptionCalibration.ValidationFailure.invalidIterations) {
            try AbsorptionCalibration.fitValidated(
                settings, to: Array(repeating: nil, count: 8), iterations: -1, simulate: forbidden)
        }
    }

    @Test("Failure from final validation propagates rather than returning selected history")
    func validationError() {
        enum Failure: Error { case cancelled }
        var calls = 0
        #expect(throws: Failure.cancelled) {
            try AbsorptionCalibration.fitValidated(
                CalibrationOutcomeAuditTests.settings,
                to: [nil, nil, nil, 1, nil, nil, nil, nil], iterations: 0
            ) { _ in
                calls += 1
                if calls == 2 { throw Failure.cancelled }
                return []
            }
        }
        #expect(calls == 2)
    }
    @Test("Final coupled-room verification is independent of historical best values")
    func coupledVerification() throws {
        let sampleRate = 48_000
        var random = SplitMix(seed: 73)
        let noise = (0..<57_600).map { _ in Float(random.nextUnit() * 2 - 1) }
        let low = DecayAnalysis.octaveBand(noise, sampleRate: sampleRate, band: 3)
        let high = DecayAnalysis.octaveBand(noise, sampleRate: sampleRate, band: 4)
        var factorVectors: [[Double]] = []
        var verificationResponse: [Float] = []
        var trials: [RoomResponseSettings] = []
        var responses: [[[Float]]] = []
        let result = try AbsorptionCalibration.fitValidated(
            CalibrationOutcomeAuditTests.settings,
            to: [nil, nil, nil, 1, 1, nil, nil, nil], tolerance: 0.005, iterations: 2
        ) { trial in
            trials.append(trial)
            let factors = trial.room.west.absorption.map { $0 / 0.2 }
            factorVectors.append(factors)
            let lowTime = factors[4] > 1.1 ? 0.7 : 1.0
            let highTime = 1.6 / factors[4]
            let channel = low.indices.map { index in
                let time = Double(index) / Double(sampleRate)
                return low[index] * Float(exp(-3 * log(10) * time / lowTime))
                    + high[index] * Float(exp(-3 * log(10) * time / highTime))
            }
            verificationResponse = channel
            responses.append([channel])
            return [channel]
        }
        let verification = try #require(result.verification)
        #expect(result.simulationCount == factorVectors.count)
        #expect(result.steps.count + 1 == factorVectors.count)
        #expect(factorVectors.last == result.selectedBest.factors)
        #expect(!factorVectors.dropLast().contains(result.selectedBest.factors))
        let historic = try #require(result.selectedBest.reverberationTime[3])
        let final = try #require(verification.reverberationTime[3])
        #expect(abs(historic - final) > 0.1)
        let replay = try #require(
            DecayAnalysis.reverberationTime(
                DecayAnalysis.measuredOctaveBand(verificationResponse, sampleRate: sampleRate, band: 3),
                sampleRate: sampleRate))
        #expect(final == replay)
        #expect(result.targetedBandCount == 2)
        #expect(result.measuredBandCount == 2)
        #expect(result.matchedBandCount == 1)
        #expect(!result.allTargetsMatched)
        guard case .outsideTolerance(let error) = result.measurements[3] else {
            Issue.record("Final 500 Hz mismatch was not classified")
            return
        }
        #expect(error == abs(final - 1))
        #expect(result.room.west.absorption[3] == 0.2 * result.selectedBest.factors[3])
        try CalibrationOutcomeWitness.write(
            name: "coupled", settings: CalibrationOutcomeAuditTests.settings,
            targets: result.targets, tolerance: result.tolerance, iterations: 2,
            trials: trials, responses: responses, result: result)
    }

    @Test("All measured targets must match, and one missing receiver is unavailable")
    func measuredCoverage() throws {
        var random = SplitMix(seed: 101)
        let noise = (0..<57_600).map { _ in Float(random.nextUnit() * 2 - 1) }
        let band = DecayAnalysis.octaveBand(noise, sampleRate: 48_000, band: 4)
        let channel = band.indices.map { index in
            band[index] * Float(exp(-3 * log(10) * Double(index) / 48_000))
        }
        let target = try #require(
            DecayAnalysis.reverberationTime(
                DecayAnalysis.measuredOctaveBand(channel, sampleRate: 48_000, band: 4),
                sampleRate: 48_000))
        let settings = CalibrationOutcomeAuditTests.settings
        let goals: [Double?] = [nil, nil, nil, nil, target, nil, nil, nil]
        let matched = try AbsorptionCalibration.fitValidated(
            settings, to: goals, tolerance: 0, iterations: 0
        ) { _ in [channel] }
        #expect(matched.targetedBandCount == 1 && matched.measuredBandCount == 1)
        #expect(matched.matchedBandCount == 1 && matched.allTargetsMatched)
        #expect(matched.measurements[4] == .matched(relativeError: 0))
        var calls = 0
        let unavailable = try AbsorptionCalibration.fitValidated(
            settings, to: goals, tolerance: 0, iterations: 0
        ) { _ in
            calls += 1
            return calls == 1 ? [channel] : [channel, Array(repeating: 0, count: channel.count)]
        }
        #expect(unavailable.selectedBest.reverberationTime[4] == target)
        #expect(unavailable.verification?.reverberationTime[4] == nil)
        #expect(unavailable.measurements[4] == .unavailable)
        #expect(!unavailable.allTargetsMatched)
    }

    @Test("Per-band assessment distinguishes unavailable, matched and unmet measurements")
    func assessment() {
        typealias Measurement = AbsorptionCalibration.TargetMeasurement
        #expect(Measurement.assess(time: 1, target: nil, tolerance: 0) == .notTargeted)
        for time in [nil, 0, -1, Double.infinity, Double.nan] as [Double?] {
            #expect(Measurement.assess(time: time, target: 1, tolerance: 0.02) == .unavailable)
        }
        #expect(Measurement.assess(time: 1, target: 1, tolerance: 0) == .matched(relativeError: 0))
        #expect(Measurement.assess(time: 1.25, target: 1, tolerance: 0.25) == .matched(relativeError: 0.25))
        #expect(
            Measurement.assess(time: 1.25, target: 1, tolerance: 0.249)
                == .outsideTolerance(relativeError: 0.25))
    }

    @Test("Saturated search preserves legacy selection and remains outside tolerance")
    func saturation() throws {
        let channel = Self.decayingChannel()
        var settings = CalibrationOutcomeAuditTests.settings
        settings.room = ShoeboxRoom(size: [8, 6, 4], material: .uniform(0.8, name: "Saturation"))
        let goals: [Double?] = [nil, nil, nil, nil, 0.01, nil, nil, nil]
        let legacy = try AbsorptionCalibration.fit(settings, to: goals, iterations: 2) { _ in [channel] }
        var rooms: [ShoeboxRoom] = []
        let result = try AbsorptionCalibration.fitValidated(settings, to: goals, iterations: 2) { trial in
            rooms.append(trial.room)
            return [channel]
        }
        #expect(rooms.count == 4 && result.steps.count == 3)
        let saturated = 0.8 * (0.99 / 0.8)
        #expect(rooms[1].west.absorption[4] == saturated)
        #expect(rooms[2].west.absorption[4] == saturated)
        #expect(result.steps.map(\.factors) == legacy.steps.map(\.factors))
        #expect(result.steps.map(\.reverberationTime) == legacy.steps.map(\.reverberationTime))
        #expect(result.selectedBest.factors == legacy.best.factors)
        #expect(result.room.west.absorption == legacy.room.west.absorption)
        #expect(rooms.last?.west.absorption == result.room.west.absorption)
        #expect(result.measuredBandCount == 1 && result.matchedBandCount == 0)
        #expect(!result.allTargetsMatched)
        guard case .outsideTolerance(let error) = result.measurements[4] else {
            Issue.record("Saturation must not imply convergence")
            return
        }
        #expect(error > result.tolerance)
        try CalibrationOutcomeWitness.write(
            name: "saturation", settings: settings, targets: goals, tolerance: result.tolerance,
            iterations: 2,
            trials: rooms.map { room in
                var trial = settings
                trial.room = room
                return trial
            }, responses: rooms.map { _ in [channel] }, result: result)
    }

    @Test("Search errors propagate before final verification")
    func searchError() {
        enum Failure: Error { case simulation }
        var calls = 0
        #expect(throws: Failure.simulation) {
            try AbsorptionCalibration.fitValidated(
                CalibrationOutcomeAuditTests.settings,
                to: [nil, nil, nil, nil, 1, nil, nil, nil]
            ) { _ in
                calls += 1
                throw Failure.simulation
            }
        }
        #expect(calls == 1)
    }

    static func decayingChannel() -> [Float] {
        var random = SplitMix(seed: 101)
        let noise = (0..<57_600).map { _ in Float(random.nextUnit() * 2 - 1) }
        let band = DecayAnalysis.octaveBand(noise, sampleRate: 48_000, band: 4)
        return band.indices.map { index in
            band[index] * Float(exp(-3 * log(10) * Double(index) / 48_000))
        }
    }

    static func measuredTime(_ channel: [Float]) -> Double? {
        DecayAnalysis.reverberationTime(
            DecayAnalysis.measuredOctaveBand(channel, sampleRate: 48_000, band: 4),
            sampleRate: 48_000)
    }
}
