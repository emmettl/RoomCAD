import Foundation
import Testing

@testable import AcousticCore

@Suite("Room parameters")
struct RoomParametersTests {
    /// Exponentially decaying random-sign noise with reverberation time `t60`, optionally with steady
    /// background noise `noiseDecibels` below the start.
    private func decay(t60: Double, noiseDecibels: Double?, seconds: Double = 3) -> [Double] {
        let rate = 48_000.0
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        func random() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(1 << 53) * 2 - 1
        }
        let delta = 3 * log(10) / t60
        return (0..<Int(seconds * rate)).map { i in
            let t = Double(i) / rate
            var sample = random() * exp(-delta * t)
            if let noiseDecibels { sample += random() * pow(10, noiseDecibels / 20) }
            return sample * sample
        }
    }

    @Test("An exponential decay gives its reverberation time, clarity, definition and centre time")
    func exponential() throws {
        let t60 = 1.2
        let p = RoomParameters.measure(
            energy: decay(t60: t60, noiseDecibels: nil), sampleRate: 48_000, noiseCompensated: false)
        let k = 6 * log(10) / t60
        for value in [p.edt, p.t20, p.t30] {
            let measured = try #require(value)
            #expect(abs(measured / t60 - 1) < 0.03, "\(measured) s against \(t60) s")
        }
        let c80 = 10 * log10((1 - exp(-k * 0.08)) / exp(-k * 0.08))
        #expect(abs(p.c80 - c80) < 0.2)
        #expect(abs(p.d50 - (1 - exp(-k * 0.05))) < 0.01)
        #expect(abs(p.centreTime / (1 / k) - 1) < 0.03)
    }

    @Test("Background noise is cut off and the missing decay added back, as Lundeby's method does")
    func noise() throws {
        let t60 = 1.2
        let noisy = decay(t60: t60, noiseDecibels: -45)
        let compensated = RoomParameters.measure(energy: noisy, sampleRate: 48_000, noiseCompensated: true)
        let raw = RoomParameters.measure(energy: noisy, sampleRate: 48_000, noiseCompensated: false)
        let t30 = try #require(compensated.t30)
        #expect(abs(t30 / t60 - 1) < 0.05, "\(t30) s against \(t60) s")
        // Without compensation the noise flattens the decay curve.
        #expect(try #require(raw.t30) > 1.1 * t60)
        // Without noise, compensation changes nothing that matters.
        let clean = decay(t60: t60, noiseDecibels: nil)
        let both = [true, false].map {
            RoomParameters.measure(energy: clean, sampleRate: 48_000, noiseCompensated: $0)
        }
        #expect(abs(try #require(both[0].t30) / #require(both[1].t30) - 1) < 0.001)
    }

    @Test("A burst of noise late in a measurement doesn't stretch the fit into the noise")
    func noiseBurst() throws {
        // As in a measured 63 Hz band whose noise has a knock in it: 10 ms 15 dB above the noise, 2.6 s
        // in. Fitting to the last block above the noise took the fit through the noise, to 3–4 s.
        let t60 = 1.2
        var noisy = decay(t60: t60, noiseDecibels: -45)
        for i in 124_800..<125_280 { noisy[i] *= pow(10, 1.5) }
        let compensated = RoomParameters.measure(energy: noisy, sampleRate: 48_000, noiseCompensated: true)
        let t30 = try #require(compensated.t30)
        #expect(abs(t30 / t60 - 1) < 0.05, "\(t30) s against \(t60) s")
    }

    @Test("The 63 Hz and 8 kHz bands are octaves, which leave out what lies below 31 Hz and above 16 kHz")
    func edgeBands() throws {
        for band in 1..<(OctaveBands.count - 1) {
            for f in stride(from: 20.0, through: 20_000, by: 37) {
                #expect(
                    OctaveBands.measurementWeight(band: band, frequency: f)
                        == OctaveBands.weight(band: band, frequency: f))
            }
        }
        for f in [10.0, 22, 31.25] { #expect(OctaveBands.measurementWeight(band: 0, frequency: f) == 0) }
        for f in [16_000.0, 18_000, 23_000] {
            #expect(OctaveBands.measurementWeight(band: OctaveBands.count - 1, frequency: f) == 0)
        }
        #expect(abs(OctaveBands.measurementWeight(band: 0, frequency: 62.5) - 1) < 1e-9)
        #expect(abs(OctaveBands.measurementWeight(band: 7, frequency: 8000) - 1) < 1e-9)

        // Tones decaying over 1 s at each band's centre, with a 22 Hz tone ringing for 4 s and an 18 kHz
        // tone gone in 0.1 s, as a source or room can have beyond the octaves. Bands open to 0 Hz and to
        // the Nyquist frequency took the 63 Hz decay as 4 s, and the 8 kHz early decay as 0.87 s.
        let rate = 48_000.0
        func tone(_ f: Double, _ t60: Double, _ amplitude: Double = 1) -> (Double) -> Double {
            { t in amplitude * sin(2 * Double.pi * f * t) * exp(-3 * log(10) / t60 * t) }
        }
        let parts = [tone(62.5, 1), tone(8000, 1), tone(22, 4), tone(18_000, 0.1, 3)]
        let samples = (0..<144_000).map { i in
            Float(parts.reduce(0) { $0 + $1(Double(i) / rate) })
        }
        // Clarity of an exponential decay of 1 s.
        let k = 6 * log(10.0)
        let c80 = 10 * log10(exp(k * 0.08) - 1)
        for band in [0, OctaveBands.count - 1] {
            let p = RoomParameters.measure(samples, sampleRate: 48_000, band: band, noiseCompensated: false)
            for value in [p.edt, p.t20, p.t30] {
                let measured = try #require(value)
                #expect(abs(measured - 1) < 0.02, "band \(band): \(measured) s against 1 s")
            }
            // At 63 Hz the first 80 ms hold five periods, which the band's own filter blurs.
            #expect(
                abs(p.c80 - c80) < (band == 0 ? 1 : 0.2), "band \(band): C80 \(p.c80) dB against \(c80) dB")
        }
    }
}
