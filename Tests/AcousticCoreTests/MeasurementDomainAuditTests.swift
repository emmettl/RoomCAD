import Foundation
import Testing

@testable import AcousticCore

/// Characterizes existing measurement domains; no checked-policy implementation is adopted here.
@Suite("Acoustic measurement domain source audit")
struct MeasurementDomainAuditTests {
    @Test("Empty and silent energy have unavailable times and nonfinite normalized parameters")
    func missingEnergy() {
        for energy in [[], Array(repeating: 0.0, count: 2400)] {
            for compensated in [false, true] {
                let parameters = RoomParameters.measure(
                    energy: energy, sampleRate: 48_000, noiseCompensated: compensated)
                #expect(parameters.edt == nil && parameters.t20 == nil && parameters.t30 == nil)
                #expect(parameters.c50 == -.infinity && parameters.c80 == -.infinity)
                #expect(parameters.d50.isNaN)
                #expect(parameters.centreTime == 0)
                #expect(throws: EncodingError.self) { try JSONEncoder().encode(parameters) }
                print(
                    "MEASUREMENT_AUDIT no-energy samples=\(energy.count) compensation=\(compensated): unavailable times, C50/C80=-infinity, D50=NaN, JSON unavailable"
                )
            }
        }
    }

    @Test("The public silent-response path retains the same unavailable serialization domain")
    func silentResponse() {
        let parameters = RoomParameters.measure(
            Array(repeating: Float.zero, count: 2400), sampleRate: 48_000, band: 4,
            noiseCompensated: false)
        #expect(parameters.t30 == nil)
        #expect(parameters.d50.isNaN)
        #expect(throws: EncodingError.self) { try JSONEncoder().encode(parameters) }
    }

    @Test("A finite constant-energy record obtains a positive decay fit from its cutoff alone")
    func cutoffOnly() throws {
        var times: [Double] = []
        for count in [2400, 4800, 9600] {
            let energy = Array(repeating: 1.0, count: count)
            let raw = RoomParameters.measure(energy: energy, sampleRate: 48_000, noiseCompensated: false)
            let compensated = RoomParameters.measure(
                energy: energy, sampleRate: 48_000, noiseCompensated: true)
            #expect(raw == compensated)
            #expect(RoomParameters.noiseCut(energy, sampleRate: 48_000) == nil)
            if count == 2400 {
                // The final backward-integral sample is only -10 log10(2400) dB,
                // so this finite record never supplies a -35 dB endpoint.
                #expect(raw.t30 == nil)
                #expect(raw.c50 == .infinity && raw.c80 == .infinity)
                #expect(raw.d50 == 1)
                #expect(throws: EncodingError.self) { try JSONEncoder().encode(raw) }
                print(
                    "MEASUREMENT_AUDIT constant-energy samples=2400: T30 unavailable, C50/C80=infinity, D50=1; nonzero energy still outside default JSON domain"
                )
                continue
            }
            let time = try #require(raw.t30)
            #expect(time.isFinite && time > 0)
            let direct = try #require(
                DecayAnalysis.reverberationTime(Array(repeating: 1, count: count), sampleRate: 48_000))
            // These APIs scale fitting coordinates at different points; do not claim
            // byte-identical arithmetic for their independently rounded fits.
            #expect(abs(time - direct) <= 4 * time.ulp)
            let expected = try #require(Self.finiteRecordTime(energy: energy))
            #expect(abs(time - expected) < 1e-10)
            times.append(time)
            print(
                "MEASUREMENT_AUDIT constant-energy samples=\(count): T30=\(time), independent finite-record fit=\(expected); no decreasing input envelope"
            )
        }
        #expect(abs(times[1] / times[0] - 2) < 0.02)
    }

    @Test("Truncation bias is separate from fitting the declared exponential decay")
    func truncatedDecay() throws {
        let rate = 48_000
        let target = 1.2
        var times: [Double] = []
        for duration in [0.12, 3.0] {
            let energy = (0..<Int(duration * Double(rate))).map {
                exp(-6 * log(10) * Double($0) / Double(rate) / target)
            }
            let parameters = RoomParameters.measure(energy: energy, sampleRate: rate, noiseCompensated: false)
            let time = try #require(parameters.t30)
            let expected = try #require(Self.finiteRecordTime(energy: energy))
            #expect(abs(time - expected) < 1e-9)
            times.append(time)
            print(
                "MEASUREMENT_AUDIT exponential duration=\(duration): input T60=\(target), measured T30=\(time), independent finite-record fit=\(expected)"
            )
        }
        #expect(times[0] < 0.8 * target)
        #expect(abs(times[1] - target) < 0.002)
    }

    /// Independent straightforward backward sum and centred OLS of the finite record.
    /// This checks the existing numerical interpretation; it adds no quality/admission policy.
    static func finiteRecordTime(energy: [Double]) -> Double? {
        var tail = 0.0
        var curve = energy.reversed().map { value -> Double in
            tail += value
            return tail
        }.reversed().map { $0 }
        let total = curve[0]
        curve = curve.map { 10 * log10($0 / total) }
        guard let first = curve.firstIndex(where: { $0 <= -5 }),
            let last = curve.firstIndex(where: { $0 <= -35 }), last > first + 1
        else { return nil }
        let count = Double(last - first + 1)
        let meanX = Double(first + last) / 2 / 48_000
        let meanY = curve[first...last].reduce(0, +) / count
        var covariance = 0.0
        var variance = 0.0
        for index in first...last {
            let x = Double(index) / 48_000 - meanX
            covariance += x * (curve[index] - meanY)
            variance += x * x
        }
        return -60 * variance / covariance
    }
}
