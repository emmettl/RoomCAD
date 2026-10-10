import CryptoKit
import Foundation

#if TRACE_SHARED_AFFINE
    import Numerics
#endif

/// Fixture-only recorder. The benchmark invokes application operations serially.
/// This file is injected into a temporary AcousticCore target, never production.
public enum AffineTrace {
    public nonisolated(unsafe) static var caseID = "unset"
    public nonisolated(unsafe) static var part = "main"
    public nonisolated(unsafe) static var events: [[String: Any]] = []
    public nonisolated(unsafe) static var cases: [[String: Any]] = []
    private nonisolated(unsafe) static var native = Data()

    public static func scalar(_ x: Double) -> [String: String] {
        ["value": String(x), "bits": String(x.bitPattern, radix: 16)]
    }
    public static func optional(_ x: Double?) -> Any {
        if let x { return scalar(x) }
        return NSNull()
    }
    private static func stored(_ data: Data, count: Int, width: Int) -> [String: Any] {
        let result: [String: Any] = [
            "offset": native.count, "count": count, "width": width,
            "sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
        ]
        native.append(data)
        return result
    }
    public static func vector(_ x: [Double]) -> [String: Any] {
        let words = x.map { $0.bitPattern.littleEndian }
        return words.withUnsafeBytes { stored(Data($0), count: x.count, width: 64) }
    }
    public static func vector(_ x: [Float]) -> [String: Any] {
        let words = x.map { $0.bitPattern.littleEndian }
        return words.withUnsafeBytes { stored(Data($0), count: x.count, width: 32) }
    }
    public static func record(_ kind: String, _ data: [String: Any]) {
        var row = data
        row["kind"] = kind
        row["case"] = caseID
        row["part"] = part
        row["sequence"] = events.count
        events.append(row)
    }
    public static func parameters(_ p: RoomParameters) -> [String: Any] {
        [
            "edt": optional(p.edt), "t20": optional(p.t20), "t30": optional(p.t30),
            "c50": scalar(p.c50), "c80": scalar(p.c80), "d50": scalar(p.d50),
            "centreTime": scalar(p.centreTime),
        ]
    }
    public static func roomEnergy(_ energy: [Double], _ rate: Int, _ compensated: Bool) {
        record(
            "room-energy", ["energy": vector(energy), "sampleRate": rate, "noiseCompensated": compensated])
    }
    public static func roomCurve(
        _ curve: [Double], _ db: [Double], _ total: Double, _ tail: Double, _ end: Int
    ) {
        record(
            "room-curve",
            [
                "curve": vector(curve), "decibels": vector(db), "total": scalar(total), "tail": scalar(tail),
                "end": end,
            ])
    }
    public static func roomWindow(
        _ db: [Double], _ first: Int, _ last: Int, _ rate: Double, _ upper: Double, _ lower: Double
    ) {
        record(
            "room-window",
            [
                "first": first, "last": last, "rate": scalar(rate), "upper": scalar(upper),
                "lower": scalar(lower), "values": vector(Array(db[first...last])),
            ])
    }
    public static func noiseSetup(
        _ means: [Double], _ levels: [Double], _ smoothed: [Double], _ block: Int, _ blocks: Int,
        _ top: Double, _ floor: Double
    ) {
        record(
            "noise-setup",
            [
                "means": vector(means), "levels": vector(levels), "smoothed": vector(smoothed),
                "block": block, "blocks": blocks, "top": scalar(top), "floor": scalar(floor),
            ])
    }
    public static func noiseWindow(_ first: Int, _ last: Int, _ floor: Double, _ top: Double) {
        record("noise-window", ["first": first, "last": last, "floor": scalar(floor), "top": scalar(top)])
    }
    public static func noiseIteration(_ crossing: Int, _ slope: Double, _ floor: Double) {
        record("noise-iteration", ["crossing": crossing, "slope": scalar(slope), "nextFloor": scalar(floor)])
    }
    public static func crossing(_ coordinate: Double, _ cut: Int, _ nextStart: Int?) {
        record(
            "noise-crossing",
            [
                "coordinate": scalar(coordinate), "cut": cut,
                "nextStart": nextStart.map { $0 as Any } ?? NSNull(),
            ])
    }
    public static func noiseTail(_ index: Int, _ level: Double, _ perSample: Double, _ tau: Double) {
        record(
            "noise-tail",
            [
                "index": index, "level": scalar(level), "perSample": scalar(perSample), "tau": scalar(tau),
                "tail": scalar(perSample * tau),
            ])
    }
    public static func legacyLine(_ values: [Double], _ offset: Int, _ slope: Double, _ intercept: Double) {
        let x = values.indices.map { Double($0 + offset) }
        record(
            "index-fit",
            [
                "x": vector(x), "y": vector(values), "offset": offset, "slope": scalar(slope),
                "intercept": scalar(intercept),
                "diagnosticPredictions": vector(x.map { intercept + slope * $0 }),
            ])
    }
    #if TRACE_SHARED_AFFINE
        public static func sharedLine(_ values: [Double], _ offset: Int, _ result: AffineLeastSquares.Result?)
        {
            let x = values.indices.map { Double($0 + offset) }
            var data: [String: Any] = ["x": vector(x), "y": vector(values), "offset": offset]
            if let r = result {
                data["slope"] = scalar(r.slope)
                data["origin"] = scalar(r.origin)
                data["valueAtOrigin"] = scalar(r.valueAtOrigin)
                data["normalizedVariance"] = scalar(r.normalizedVariance)
                data["covarianceCancellationRatio"] = scalar(r.covarianceCancellationRatio)
                data["diagnosticPredictions"] = vector(x.map { (try? r.value(at: $0)) ?? .nan })
            } else {
                data["unavailable"] = true
            }
            record("index-fit", data)
        }
        public static func sharedDecayFit(
            _ curve: [Double], _ first: Int, _ last: Int, _ rate: Int, _ result: AffineLeastSquares.Result
        ) {
            let x = (first...last).map { Double($0) / Double(rate) }
            record(
                "time-fit",
                [
                    "x": vector(x), "y": vector(Array(curve[first...last])), "first": first, "last": last,
                    "sampleRate": rate, "slope": scalar(result.slope), "origin": scalar(result.origin),
                    "valueAtOrigin": scalar(result.valueAtOrigin),
                    "diagnosticPredictions": vector(x.map { (try? result.value(at: $0)) ?? .nan }),
                ])
        }
    #endif
    public static func decayWindow(
        _ samples: [Float], _ curve: [Double], _ rate: Int, _ upper: Double, _ lower: Double, _ first: Int,
        _ last: Int
    ) {
        record(
            "decay-window",
            [
                "samples": vector(samples), "curve": vector(curve), "sampleRate": rate,
                "upper": scalar(upper), "lower": scalar(lower), "first": first, "last": last,
            ])
    }
    public static func legacyDecayFit(
        _ curve: [Double], _ first: Int, _ last: Int, _ rate: Int, _ slope: Double
    ) {
        let x = (first...last).map { Double($0) / Double(rate) }
        let y = Array(curve[first...last])
        let b = (y.reduce(0, +) - slope * x.reduce(0, +)) / Double(y.count)
        record(
            "time-fit",
            [
                "x": vector(x), "y": vector(y), "first": first, "last": last, "sampleRate": rate,
                "slope": scalar(slope), "diagnosticIntercept": scalar(b),
                "diagnosticPredictions": vector(x.map { b + slope * $0 }),
            ])
    }
    public static func probe(_ values: [Double], _ offset: Int) {
        _ = RoomParameters.line(values, offset: offset)
    }
    public static func finish(_ output: URL) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try native.write(to: output.appendingPathComponent("native.bin"))
        let report: [String: Any] = [
            "schemaVersion": 1, "nativeFormat": "complete little-endian IEEE754", "cases": cases,
            "events": events,
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]).write(
            to: output.appendingPathComponent("application.json"))
    }
}
