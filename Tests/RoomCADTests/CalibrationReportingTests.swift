import Foundation
import Testing

@testable import AcousticCore
@testable import RoomCAD

@MainActor
@Suite("Calibration measurement coverage")
struct CalibrationReportingTests {
    @Test("A measured target does not imply the unavailable target was measured")
    func partialCoverage() {
        let step = AbsorptionCalibration.Step(
            reverberationTime: [1, nil, nil, nil, nil, nil, nil, nil],
            factors: Array(repeating: 1, count: 8))
        let report = AbsorptionFitter.summary(
            step, simulations: 1, target: [1, 1, nil, nil, nil, nil, nil, nil])
        #expect(report.contains("1 of 2 targeted bands"))
        #expect(report.contains("unavailable"))
        #expect(!report.hasSuffix("of the targets."))
    }

    @Test("An entirely unavailable calibration reports no measured agreement")
    func unavailableCoverage() {
        let step = AbsorptionCalibration.Step(
            reverberationTime: Array(repeating: nil, count: 8),
            factors: Array(repeating: 1, count: 8))
        let report = AbsorptionFitter.summary(
            step, simulations: 1, target: [1, 1, nil, nil, nil, nil, nil, nil])
        #expect(report.contains("unavailable for all 2 targeted bands"))
        #expect(!report.contains("within"))
    }

    @Test("Final verification reports no targets and unavailable measurements explicitly")
    func verifiedUnavailable() throws {
        let settings = RoomResponseSettings(
            room: ShoeboxRoom(size: [8, 6, 4], material: .uniform(0.2, name: "Verification")),
            source: RoomPoint(name: "Source", position: [2, 3, 1.5]),
            receivers: [RoomPoint(name: "Receiver", position: [6, 2.5, 1.2])])
        let noTargets = try AbsorptionCalibration.fitValidated(
            settings, to: Array(repeating: nil, count: 8)
        ) { _ in [] }
        #expect(
            AbsorptionFitter.validatedSummary(noTargets) == "No calibration targets; absorption unchanged.")
        let unavailable = try AbsorptionCalibration.fitValidated(
            settings, to: [nil, nil, nil, 1, 1, nil, nil, nil]
        ) { _ in [] }
        let report = AbsorptionFitter.validatedSummary(unavailable)
        #expect(report.contains("final preview T30 unavailable for all 2 targeted bands"))
        #expect(report.contains("in 0 steps"))
        #expect(!report.contains("within"))
    }

    @Test("Final preview reporting describes measured agreement and safely formats huge errors")
    func verifiedMeasuredAndHugeError() throws {
        let settings = RoomResponseSettings(
            room: ShoeboxRoom(size: [8, 6, 4], material: .uniform(0.2, name: "Verification")),
            source: RoomPoint(name: "Source", position: [2, 3, 1.5]),
            receivers: [RoomPoint(name: "Receiver", position: [6, 2.5, 1.2])])
        var random = SplitMix(seed: 101)
        let noise = (0..<57_600).map { _ in Float(random.nextUnit() * 2 - 1) }
        let band = DecayAnalysis.octaveBand(noise, sampleRate: 48_000, band: 4)
        let channel = band.indices.map { index in
            band[index] * Float(exp(-3 * log(10) * Double(index) / 48_000))
        }
        let time = try #require(
            DecayAnalysis.reverberationTime(
                DecayAnalysis.measuredOctaveBand(channel, sampleRate: 48_000, band: 4), sampleRate: 48_000))
        let measured = try AbsorptionCalibration.fitValidated(
            settings, to: [nil, nil, nil, nil, time, nil, nil, nil], tolerance: 0, iterations: 0
        ) { _ in [channel] }
        #expect(
            AbsorptionFitter.validatedSummary(measured).contains(
                "final preview T30 within 0% of the targets."))
        let huge = try AbsorptionCalibration.fitValidated(
            settings, to: [nil, nil, nil, nil, Double.leastNonzeroMagnitude, nil, nil, nil], iterations: 0
        ) { _ in [channel] }
        #expect(huge.matchedBandCount == 0)
        #expect(AbsorptionFitter.validatedSummary(huge).contains("relative error too large to display"))
    }
}
