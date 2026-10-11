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
}
