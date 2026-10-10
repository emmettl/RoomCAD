import Foundation
import Testing

@testable import AcousticCore

@Suite("Shared affine application boundary")
struct AffineAdoptionTests {
    @Test("Noise estimation clamps before converting an enormous five-decibel interval")
    func boundedNoiseStart() {
        #expect(RoomParameters.noiseFloorStart(crossing: 20, slope: -0.1, blocks: 100) == 71)
        #expect(RoomParameters.noiseFloorStart(crossing: 20, slope: -0.13, blocks: 100) == 59)
        #expect(RoomParameters.noiseFloorStart(crossing: 95, slope: -1, blocks: 100) == 90)
        #expect(
            RoomParameters.noiseFloorStart(crossing: 20, slope: -.leastNonzeroMagnitude, blocks: 100)
                == 90)
        #expect(RoomParameters.noiseFloorStart(crossing: 20, slope: -.infinity, blocks: 100) == nil)
        #expect(RoomParameters.noiseFloorStart(crossing: 20, slope: 0, blocks: 100) == nil)
        #expect(RoomParameters.noiseFloorStart(crossing: -1, slope: -1, blocks: 100) == nil)
        #expect(RoomParameters.noiseFloorStart(crossing: 100, slope: -1, blocks: 100) == nil)
        #expect(RoomParameters.noiseFloorStart(crossing: 2, slope: -1, blocks: 20) == nil)
    }

    @Test("A delayed exponential retains seconds while unavailable fits return nil")
    func delayedDecay() throws {
        let rate = 48_000
        let duration = 0.12
        let delay = 480_000
        let samples =
            [Float](repeating: 0, count: delay)
            + (0..<24_000).map { Float(exp(-3 * log(10) * Double($0) / Double(rate) / duration)) }
        let time = try #require(DecayAnalysis.reverberationTime(samples, sampleRate: rate))
        #expect(abs(time / duration - 1) < 1e-6)
        #expect(DecayAnalysis.reverberationTime(samples, sampleRate: 0) == nil)
        #expect(DecayAnalysis.reverberationTime(samples, sampleRate: -rate) == nil)
        #expect(DecayAnalysis.reverberationTime([Float](repeating: 0, count: 16), sampleRate: rate) == nil)
    }
}
