import SceneModel
import Testing
import simd

@testable import AcousticCore

@Suite("Shared Double box query adoption")
struct SharedBoxQueryTests {
    private func original(_ zone: FittingZone, origin: SIMD3<Double>, direction: SIMD3<Double>, limit: Double)
        -> ClosedRange<Double>?
    {
        let low = zone.low
        let high = zone.high
        var enter = 0.0
        var leave = limit
        for a in 0..<3 {
            if direction[a] == 0 {
                guard origin[a] >= low[a], origin[a] <= high[a] else { return nil }
                continue
            }
            var t0 = (low[a] - origin[a]) / direction[a]
            var t1 = (high[a] - origin[a]) / direction[a]
            if t0 > t1 { swap(&t0, &t1) }
            enter = max(enter, t0)
            leave = min(leave, t1)
            if enter >= leave { return nil }
        }
        return enter...leave
    }

    private func zone(_ low: SIMD3<Double>, _ high: SIMD3<Double>) -> FittingZone {
        FittingZone(
            name: "Query fixture", low: low, high: high, density: 0.5,
            absorption: Array(repeating: 0.4, count: OctaveBands.count))
    }

    @Test("Core closed contacts retain the application's positive-path attenuation rule")
    func contacts() {
        let seating = zone(.zero, [1, 1, 1])
        #expect(
            BoxQuery.intersection(
                min: seating.low, max: seating.high,
                origin: [-1, 1, 0.5], direction: [1, -1, 0]) == 1...1)
        #expect(seating.overlap(origin: [-1, 1, 0.5], direction: [1, -1, 0], limit: 5) == nil)
        #expect(seating.overlap(origin: [1, 0.5, 0.5], direction: [1, 0, 0], limit: 5) == nil)
        #expect(seating.overlap(origin: [1, 0.5, 0.5], direction: [-1, 0, 0], limit: 5) == 0...1)
        #expect(seating.overlap(origin: [0.5, 0.5, 0.5], direction: .zero, limit: 5) == 0...5)
        #expect(seating.overlap(origin: [2, 0.5, 0.5], direction: .zero, limit: 5) == nil)
        #expect(seating.overlap(origin: [0.5, 0.5, 0.5], direction: .zero, limit: 0) == 0...0)
        #expect(seating.overlap(origin: [0.5, 0.5, 0.5], direction: [1, 0, 0], limit: 0) == nil)
        #expect([seating].depth(from: [-1, 1, 0.5], to: [1, -1, 0.5]) == 0)
        #expect(abs([seating].depth(from: [-1, 0.5, 0.5], to: [2, 0.5, 0.5]) - 0.5) < 1e-15)
    }

    @Test("Full native endpoints match the protected original over acoustic ray and segment cases")
    func parity() {
        let directions: [SIMD3<Double>] = [
            .zero, [1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, 0, -1],
            [1, 1, 1], [-1, 0.25, 0.5], [1e-12, 1, 0], [0.3, -0.7, 0.2],
        ]
        for offset: SIMD3<Double> in [.zero, [19.25, -3.5, 7], [Double(1 << 30), 0, 0]] {
            let seating = zone(offset, offset + SIMD3(0.125, 1, 2))
            for x: Double in [-1, 0, 0.0625, 0.125, 1] {
                for y: Double in [-1, 0, 0.5, 1, 2] {
                    for z: Double in [-1, 0, 1, 2, 3] {
                        let origin = offset + SIMD3(x, y, z)
                        for direction in directions {
                            for limit: Double in [0, 0.0625, 1, 10] {
                                let old = original(
                                    seating, origin: origin, direction: direction, limit: limit)
                                let shared = seating.overlap(
                                    origin: origin, direction: direction, limit: limit)
                                #expect(old?.lowerBound.bitPattern == shared?.lowerBound.bitPattern)
                                #expect(old?.upperBound.bitPattern == shared?.upperBound.bitPattern)
                            }
                        }
                    }
                }
            }
        }
    }
}
