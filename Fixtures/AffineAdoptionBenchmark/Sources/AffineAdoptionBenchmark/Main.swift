import Foundation
import ImpulseResponseKit
import RoomDocument
import simd

@testable import AcousticCore

@main struct Main {
    static func main() throws {
        let output = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ROOMCAD_AFFINE_OUTPUT"]!)
        let source = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let receiver = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        func metadata<T: Encodable>(_ value: T) throws -> Any {
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
        }
        func cut(_ value: (index: Int, tail: Double)?) -> Any {
            if let value {
                return ["index": value.index, "tail": AffineTrace.scalar(value.tail)] as [String: Any]
            }
            return NSNull()
        }
        func measuredEnergy(
            _ id: String, _ energy: [Double], _ rate: Int, _ compensated: Bool, _ parameters: [String: Any]
        ) {
            AffineTrace.caseID = id
            AffineTrace.part = "measure"
            let input = AffineTrace.vector(energy)
            let p = RoomParameters.measure(energy: energy, sampleRate: rate, noiseCompensated: compensated)
            AffineTrace.part = "noise-cut"
            let noise = RoomParameters.noiseCut(energy, sampleRate: rate)
            AffineTrace.cases.append([
                "id": id, "family": "energy", "sampleRate": rate, "noiseCompensated": compensated,
                "parameters": parameters, "energy": input, "roomParameters": AffineTrace.parameters(p),
                "noiseCut": cut(noise),
            ])
        }
        func noisyEnergy(_ t60: Double, _ noiseDB: Double?, _ seconds: Double, _ rate: Int) -> [Double] {
            var state: UInt64 = 0x9E37_79B9_7F4A_7C15
            func random() -> Double {
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double(state >> 11) / Double(1 << 53) * 2 - 1
            }
            let delta = 3 * log(10) / t60
            return (0..<Int(seconds * Double(rate))).map { i in
                var sample = random() * exp(-delta * Double(i) / Double(rate))
                if let noiseDB { sample += random() * pow(10, noiseDB / 20) }
                return sample * sample
            }
        }
        for rate in [8000, 48000] {
            for compensation in [false, true] {
                let t60 = 1.2
                let energy = (0..<Int(3 * Double(rate))).map {
                    exp(-6 * log(10) * Double($0) / Double(rate) / t60)
                }
                measuredEnergy(
                    "analytic/\(rate)/\(compensation)", energy, rate, compensation,
                    ["t60": t60, "seconds": 3, "profile": "exact exponential energy"])
            }
        }
        for burst in [false, true] {
            var energy = noisyEnergy(1.2, -45, 3, 48000)
            if burst { for i in 124800..<125280 { energy[i] *= pow(10, 1.5) } }
            for compensation in [false, true] {
                measuredEnergy(
                    "noise/\(burst)/\(compensation)", energy, 48000, compensation,
                    [
                        "t60": 1.2, "noiseDB": -45, "seconds": 3, "lateBurst": burst,
                        "seed": "9e3779b97f4a7c15",
                    ])
            }
        }
        measuredEnergy("silent", [Double](repeating: 0, count: 64), 48000, false, [:])
        measuredEnergy("short", [1, 0.1, 0.01], 48000, true, [:])
        for frames in [7, 8, 9] {
            measuredEnergy(
                "threshold/\(frames)", (0..<frames).map { pow(10, -Double($0) * 5 / 10) }, 8000, false,
                ["decibelsPerSample": -5])
        }
        for offset in [0, 1_000_000_000] {
            AffineTrace.caseID = "probe/index/\(offset)"
            AffineTrace.part = "index-probe"
            let values = (0..<8).map { -10 - Double($0) / 16 }
            AffineTrace.probe(values, offset)
            AffineTrace.cases.append([
                "id": AffineTrace.caseID, "family": "index-probe", "offset": offset,
                "values": AffineTrace.vector(values),
            ])
        }
        for delay in [0, 480_000] {
            AffineTrace.caseID = "time/delayed/\(delay)"
            AffineTrace.part = "reverberation"
            let samples =
                [Float](repeating: 0, count: delay)
                + (0..<24_000).map { Float(exp(-3 * log(10) * Double($0) / 48000 / 0.12)) }
            let time = DecayAnalysis.reverberationTime(samples, sampleRate: 48000)
            AffineTrace.cases.append([
                "id": AffineTrace.caseID, "family": "time", "sampleRate": 48000, "delay": delay, "t60": 0.12,
                "samples": AffineTrace.vector(samples), "rt": AffineTrace.optional(time),
                "curve": AffineTrace.vector(DecayAnalysis.decayCurve(samples)),
            ])
        }
        for rate in [0, 48000] {
            AffineTrace.caseID = "time/unavailable/\(rate)"
            AffineTrace.part = "reverberation"
            let samples = [Float](repeating: 0, count: 64)
            let time = DecayAnalysis.reverberationTime(samples, sampleRate: rate)
            AffineTrace.cases.append([
                "id": AffineTrace.caseID, "family": "time-unavailable", "sampleRate": rate,
                "samples": AffineTrace.vector(samples), "rt": AffineTrace.optional(time),
            ])
        }
        let input = (0..<24000).map { i in
            let t = Double(i) / 48000
            return Float(
                (sin(2 * Double.pi * 62.5 * t) + sin(2 * Double.pi * 8000 * t) + 0.2
                    * sin(2 * Double.pi * 22 * t) + 0.3 * sin(2 * Double.pi * 18000 * t))
                    * exp(-3 * log(10) * t / 0.12))
        }
        for band in 0..<OctaveBands.count {
            for measured in [false, true] {
                AffineTrace.caseID = "band/\(band)/\(measured)"
                AffineTrace.part = "filter"
                let filtered =
                    measured
                    ? DecayAnalysis.measuredOctaveBand(input, sampleRate: 48000, band: band)
                    : DecayAnalysis.octaveBand(input, sampleRate: 48000, band: band)
                AffineTrace.part = "reverberation"
                let time = DecayAnalysis.reverberationTime(filtered, sampleRate: 48000)
                AffineTrace.part = "measure"
                let onset = RoomParameters.onset(filtered)
                let energy = filtered[onset...].map { Double($0) * Double($0) }
                let p = RoomParameters.measure(energy: energy, sampleRate: 48000, noiseCompensated: false)
                AffineTrace.cases.append([
                    "id": AffineTrace.caseID, "family": "band", "sampleRate": 48000, "band": band,
                    "measuredWeight": measured, "samples": AffineTrace.vector(input),
                    "filtered": AffineTrace.vector(filtered), "onset": onset,
                    "energy": AffineTrace.vector(energy), "rt": AffineTrace.optional(time),
                    "roomParameters": AffineTrace.parameters(p),
                ])
            }
        }
        func summary(_ value: ResponseSummary) -> [String: Any] {
            [
                "duration": AffineTrace.scalar(value.duration),
                "earlyDuration": AffineTrace.scalar(value.earlyDuration),
                "channels": value.channels.map { c in
                    [
                        "name": c.name, "envelope": AffineTrace.vector(c.envelope),
                        "spectrum": AffineTrace.vector(c.spectrum), "early": AffineTrace.vector(c.early),
                        "reverberationTime": c.reverberationTime.map(AffineTrace.optional),
                    ] as [String: Any]
                },
            ]
        }
        let waveSettings = RoomResponseSettings(
            room: ShoeboxRoom(size: [2, 2, 2], material: .uniform(0.2, name: "Plaster")),
            source: RoomPoint(id: source, name: "S", position: [0.7, 0.8, 1]),
            receivers: [RoomPoint(id: receiver, name: "R", position: [1.4, 1.2, 1])], airAbsorption: false,
            duration: 0.4, maximumReflectionOrder: 6, diffuseRays: 1000, lowFrequencyModel: true,
            crossoverFrequency: 80)
        for backend in ["cpu", "metal"] {
            AffineTrace.caseID = "wave/generated/\(backend)"
            AffineTrace.part = "generate"
            let generated = try RoomResponseGenerator.generate(waveSettings) { solver in
                var configured = solver
                configured.engine = backend == "cpu" ? .cpu : .gpu
                return configured
            }
            precondition((generated.diagnostics.waveRuns ?? 0) > 0)
            if backend == "metal" { precondition((generated.diagnostics.waveGPURuns ?? 0) > 0) }
            AffineTrace.part = "response-summary"
            let waveSummary = ResponseSummary(generated)
            AffineTrace.cases.append([
                "id": AffineTrace.caseID, "family": "wave", "backend": backend,
                "settings": try metadata(waveSettings), "metadata": try metadata(generated.response.metadata),
                "waveRuns": generated.diagnostics.waveRuns ?? 0,
                "gpuRuns": generated.diagnostics.waveGPURuns ?? 0,
                "channels": generated.response.channels.map(AffineTrace.vector),
                "summary": summary(waveSummary),
            ])
        }

        // The two existing absorption calibration tests' actual generation/feedback operations.
        for model in ["geometrical", "erratic-band"] {
            let initial: ShoeboxRoom
            if model == "geometrical" {
                var room = ShoeboxRoom(
                    size: [9, 6, 4], material: .uniform(0.05, scattering: 0.1, name: "Plaster"))
                room.floor = .uniform(0.5, scattering: 0.3, name: "Audience")
                initial = room
            } else {
                initial = ShoeboxRoom(size: [8, 6, 4], material: .uniform(0.2, name: "Plaster"))
            }
            let settings = RoomResponseSettings(
                room: initial, source: RoomPoint(id: source, name: "S", position: [2, 3, 1.5]),
                receivers: [
                    RoomPoint(
                        id: receiver, name: "R",
                        position: model == "geometrical" ? [6.5, 2.2, 1.2] : [6, 2.5, 1.2])
                ], airAbsorption: false, duration: model == "geometrical" ? 1.2 : 2,
                maximumReflectionOrder: 12, diffuseRays: 10000)
            let target: [Double?] =
                model == "geometrical"
                ? [nil, nil, 1.2, 1.2, 1.2, 1.2, nil, nil] : [1.2, nil, nil, 1, 1, 1, 1, 1]
            var random = SplitMix(seed: 5)
            let noise = (0..<96000).map { _ in Float(random.nextUnit() * 2 - 1) }
            let bands = (0..<OctaveBands.count).map {
                DecayAnalysis.octaveBand(noise, sampleRate: 48000, band: $0)
            }
            var calls = 0
            var trials: [[String: Any]] = []
            AffineTrace.caseID = "calibration/\(model)"
            AffineTrace.part = "feedback"
            let fitted = try AbsorptionCalibration.fit(
                settings, to: target, tolerance: model == "geometrical" ? 0.03 : 0.01
            ) { trial in
                AffineTrace.part = "simulate-\(calls)"
                calls += 1
                let channels: [[Float]]
                var details: [String: Any] = [:]
                if model == "geometrical" {
                    let response = try RoomResponseGenerator.generate(trial)
                    channels = response.response.channels
                    details["metadata"] = try metadata(response.response.metadata)
                } else {
                    let factors = trial.room.west.absorption.map { $0 / 0.2 }
                    var channel = [Float](repeating: 0, count: noise.count)
                    for band in 0..<OctaveBands.count {
                        let time =
                            band == 0
                            ? [1.6, 0.9, 1.7, 1.25, 2, 1.4][min(calls - 1, 5)]
                            : band >= 3 ? 1.5 / factors[band] : 1.5
                        for i in channel.indices {
                            channel[i] += bands[band][i] * Float(exp(-3 * log(10) * Double(i) / 48000 / time))
                        }
                    }
                    channels = [channel]
                }
                details["settings"] = try metadata(trial)
                details["channels"] = channels.map(AffineTrace.vector)
                details["call"] = calls - 1
                trials.append(details)
                AffineTrace.part = "measure-\(calls - 1)"
                return channels
            }
            AffineTrace.cases.append([
                "id": AffineTrace.caseID, "family": "calibration", "model": model,
                "settings": try metadata(settings), "target": target.map(AffineTrace.optional),
                "tolerance": model == "geometrical" ? 0.03 : 0.01, "trials": trials,
                "steps": fitted.steps.map {
                    [
                        "factors": AffineTrace.vector($0.factors),
                        "reverberationTime": $0.reverberationTime.map(AffineTrace.optional),
                    ] as [String: Any]
                },
                "best": [
                    "factors": AffineTrace.vector(fitted.best.factors),
                    "reverberationTime": fitted.best.reverberationTime.map(AffineTrace.optional),
                ] as [String: Any], "room": try metadata(fitted.room),
            ])
        }
        try AffineTrace.finish(output)
        print(
            "Retained \(AffineTrace.cases.count) complete actual application cases and \(AffineTrace.events.count) source-bound trace events"
        )
    }
}
