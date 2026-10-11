import Foundation
import Testing

@testable import AcousticCore

@Suite("Calibration outcome source audit")
struct CalibrationOutcomeAuditTests {
    static var settings: RoomResponseSettings {
        RoomResponseSettings(
            room: ShoeboxRoom(size: [8, 6, 4], material: .uniform(0.2, name: "Audit")),
            source: RoomPoint(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!, name: "Source",
                position: [2, 3, 1.5]),
            receivers: [
                RoomPoint(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!, name: "Receiver",
                    position: [6, 2.5, 1.2])
            ], airAbsorption: false, duration: 1.2)
    }

    @Test("Unavailable target measurements are retained as nil with unchanged factors")
    func unavailable() throws {
        var calls = 0
        let result = try AbsorptionCalibration.fit(
            Self.settings, to: [nil, nil, nil, 1, nil, nil, nil, nil]
        ) { _ in
            calls += 1
            return [[Float](repeating: 0, count: 2048)]
        }
        #expect(calls == 1)
        #expect(result.steps.count == 1)
        #expect(result.best.reverberationTime[3] == nil)
        #expect(result.best.factors == Array(repeating: 1, count: 8))
        #expect(result.room.west.absorption == Self.settings.room.west.absorption)
        print(
            "CALIBRATION_AUDIT unavailable: calls=\(calls), measured=0, target-count=1; no convergence evidence"
        )
    }

    @Test("The historic per-band best report is distinct from a coupled assembled room measurement")
    func coupledBandAssembly() throws {
        let sampleRate = 48_000
        var random = SplitMix(seed: 73)
        let noise = (0..<57_600).map { _ in Float(random.nextUnit() * 2 - 1) }
        let low = DecayAnalysis.octaveBand(noise, sampleRate: sampleRate, band: 3)
        let high = DecayAnalysis.octaveBand(noise, sampleRate: sampleRate, band: 4)
        var trials: [[Double]] = []
        func response(_ trial: RoomResponseSettings, record: Bool) -> [[Float]] {
            let factors = trial.room.west.absorption.map { $0 / 0.2 }
            if record { trials.append(factors) }
            // Deliberately coupled synthetic response: changing 1 kHz also changes 500 Hz.
            // This is a source-contract counterexample, not a model of a measured room.
            let lowTime = factors[4] > 1.1 ? 0.7 : 1.0
            let highTime = 1.6 / factors[4]
            let channel = low.indices.map { index in
                let time = Double(index) / Double(sampleRate)
                return low[index] * Float(exp(-3 * log(10) * time / lowTime))
                    + high[index] * Float(exp(-3 * log(10) * time / highTime))
            }
            return [channel]
        }
        let targets: [Double?] = [nil, nil, nil, 1, 1, nil, nil, nil]
        let result = try AbsorptionCalibration.fit(
            Self.settings, to: targets, tolerance: 0.005, iterations: 2
        ) { response($0, record: true) }
        var assembled = Self.settings
        assembled.room = result.room
        let actual = response(assembled, record: false)[0]
        let measured = [3, 4].map { band in
            DecayAnalysis.reverberationTime(
                DecayAnalysis.measuredOctaveBand(actual, sampleRate: sampleRate, band: band),
                sampleRate: sampleRate)
        }
        let stored = try #require(result.best.reverberationTime[3])
        let final = try #require(measured[0])
        #expect(!trials.contains(result.best.factors))
        #expect(abs(stored - final) > 0.1)
        print(
            "CALIBRATION_AUDIT coupled: trials=\(trials), selected=\(result.best.factors), historic=\(result.best.reverberationTime), assembled=\(measured)"
        )
    }
}
