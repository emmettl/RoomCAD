import Audition
import CryptoKit
import Foundation
import ImpulseResponseKit
import simd

@testable import AcousticCore

@main struct Main {
    static func main() throws {
        let output = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ROOMCAD_FFT_OUTPUT"]!)
        var records: [[String: Any]] = []
        let nativeURL = output.appendingPathComponent("native.bin")
        _ = FileManager.default.createFile(atPath: nativeURL.path, contents: nil)
        let native = try FileHandle(forWritingTo: nativeURL)
        defer { try? native.close() }
        var offset = 0
        func stored(_ data: Data, count: Int, width: Int) -> [String: Any] {
            try! native.write(contentsOf: data)
            let record: [String: Any] = [
                "offset": offset, "count": count, "width": width,
                "sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            ]
            offset += data.count
            return record
        }
        func doubles(_ x: [Double]) -> [String: Any] {
            let words = x.map { $0.bitPattern.littleEndian }
            return words.withUnsafeBytes { stored(Data($0), count: x.count, width: 64) }
        }
        func floats(_ x: [Float]) -> [String: Any] {
            let words = x.map { $0.bitPattern.littleEndian }
            return words.withUnsafeBytes { stored(Data($0), count: x.count, width: 32) }
        }
        for rate in [8000, 48000] {
            for frames in [65, 1025] {
                for cutoff in [0.0, 80] {
                    for profile in ["equal", "varying"] {
                        var renderer = BandRenderer(
                            sampleRate: rate, frames: frames, lowFrequencyCutoff: cutoff)
                        var arrivals: [[String: Any]] = []
                        for (j, sample) in [0.0, 0.37, 12.25, Double(frames - 1) - 0.61].enumerated() {
                            let gains = (0..<OctaveBands.count).map { b in
                                profile == "equal" ? 0.125 : Double((b + j * 3) % 7 - 3) / 16
                            }
                            renderer.add(delay: sample / Double(rate), gains: gains)
                            arrivals.append(["sample": sample, "gains": doubles(gains)])
                        }
                        records.append([
                            "id": "bands/\(rate)/\(frames)/\(Int(cutoff))/\(profile)", "kind": "bands",
                            "rate": rate, "frames": frames, "cutoff": cutoff, "profile": profile,
                            "arrivals": arrivals, "output": floats(renderer.render()),
                        ])
                    }
                }
            }
        }
        for rate in [8000, 48000] {
            for count in [65, 1025, 4097] {
                let x = (0..<count).map { i in
                    Float(Double((i * 7) % 31 - 15) / 32 * exp(-Double(i) / Double(max(1, count / 6))))
                }
                for band in 0..<OctaveBands.count {
                    let rendered = DecayAnalysis.octaveBand(x, sampleRate: rate, band: band)
                    let measured = DecayAnalysis.measuredOctaveBand(x, sampleRate: rate, band: band)
                    records.append([
                        "id": "decay/\(rate)/\(count)/\(band)", "kind": "decay", "rate": rate, "count": count,
                        "band": band, "input": floats(x), "rendered": floats(rendered),
                        "measured": floats(measured), "curve": doubles(DecayAnalysis.decayCurve(rendered)),
                        "rt": DecayAnalysis.reverberationTime(rendered, sampleRate: rate).map { String($0) }
                            ?? "nil",
                    ])
                }
                let high = Double(rate) * 0.4
                let spectrum = ResponseComparison.spectrumLevels(
                    x, sampleRate: rate, low: 80, high: high, pointsPerOctave: 12, smoothing: 0.25)
                records.append([
                    "id": "comparison/\(rate)/\(count)", "kind": "comparison", "rate": rate, "count": count,
                    "input": floats(x), "frequencies": doubles(spectrum.frequencies),
                    "levels": doubles(spectrum.levels),
                    "fine": doubles(ResponseComparison.fineStructure(spectrum.levels, pointsPerOctave: 12)),
                    "early": doubles(ResponseComparison.earlyReflections(x, sampleRate: rate)),
                    "energy": doubles(
                        ResponseComparison.energyTimeCurve(x, sampleRate: rate, duration: 0.03, bin: 0.001)),
                    "correlation": String(ResponseComparison.correlation(spectrum.levels, spectrum.levels)),
                ])
            }
        }
        let metadataChannels = [
            ResponseMetadata.Channel(
                name: "A", sourceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                receiverID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!),
            ResponseMetadata.Channel(
                name: "B", sourceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                receiverID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!),
        ]
        for rate in [8000, 48000] {
            for profile in ["clicks", "burst"] {
                let clip =
                    profile == "clicks"
                    ? DryClip.clicks(sampleRate: rate) : DryClip.noiseBurst(sampleRate: rate)
                for channels in [1, 2] {
                    let responses = (0..<channels).map { c in
                        (0..<257).map { i in
                            [0, 4, 64, 127, 256].contains(i)
                                ? Float(Double((i * 3 + c * 7) % 17 - 8) / 16) : 0
                        }
                    }
                    let response = try ImpulseResponse(
                        channels: responses,
                        metadata: ResponseMetadata(
                            sampleRate: rate, frameCount: 257,
                            channels: Array(metadataChannels.prefix(channels)), content: .complete,
                            gainConvention: "FFT adoption",
                            usableBand: .init(lowerHz: 20, upperHz: Double(rate) / 2),
                            model: "Numerical conformance", assumptions: [], generator: "FFTAdoptionBenchmark"
                        ))
                    let preview = try AuditionPreview(clip: clip, response: response)
                    var mixes: [[String: Any]] = []
                    for match in [false, true] {
                        for mix in [Float(0), 0.3, 1] {
                            mixes.append([
                                "match": match, "mix": String(Double(mix)),
                                "channels": preview.mixed(wetMix: mix, matchLoudness: match).map(floats),
                            ])
                        }
                    }
                    records.append([
                        "id": "audition/\(rate)/\(profile)/\(channels)", "kind": "audition", "rate": rate,
                        "profile": profile, "receivers": channels, "clip": floats(clip.samples),
                        "responses": responses.map(floats), "dry": preview.dry.map(floats),
                        "wet": preview.wet.map(floats), "matchingGain": String(Double(preview.matchingGain)),
                        "dryPeak": String(Double(preview.dryPeak)),
                        "wetPeak": String(Double(preview.wetPeak)), "mixes": mixes,
                    ])
                }
            }
        }
        for rate in [8000, 48000] {
            for cutoff in [0.0, 80] {
                let room = ShoeboxRoom(
                    size: SIMD3(5, 4, 3), material: .uniform(0.2, name: "Numerical absorption"))
                let settings = RoomResponseSettings(
                    room: room,
                    source: .init(id: metadataChannels[0].sourceID, name: "S", position: SIMD3(1, 1, 1.5)),
                    receivers: [
                        .init(id: metadataChannels[0].receiverID, name: "A", position: SIMD3(2, 2, 1.5)),
                        .init(id: metadataChannels[1].receiverID, name: "B", position: SIMD3(3, 2, 1.5)),
                    ], airAbsorption: true, sampleRate: rate, duration: 0.04, maximumReflectionOrder: 3,
                    lowFrequencyCutoff: cutoff, diffuseRays: 64, randomSeed: 71, lowFrequencyModel: false)
                let result = try RoomResponseGenerator.generate(settings)
                records.append([
                    "id": "generator/\(rate)/\(Int(cutoff))", "kind": "generator", "rate": rate,
                    "cutoff": cutoff, "frames": Int((0.04 * Double(rate)).rounded()),
                    "channels": result.response.channels.map(floats),
                ])
            }
        }
        let sceneURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("scene.json")
        let scene = try ValidationScene.load(sceneURL)
        for rate in [8000, 48000] {
            let result = try scene.generate(
                set: "numerical", source: "S", receivers: ["A", "B"], duration: 0.04, lowFrequencyModel: false
            ) { settings in
                settings.sampleRate = rate
                settings.maximumReflectionOrder = 3
                settings.diffuseRays = 64
                settings.randomSeed = 71
                settings.lowFrequencyCutoff = 0
            }
            records.append([
                "id": "drivers/\(rate)", "kind": "drivers", "rate": result.sampleRate,
                "frames": Int((0.04 * Double(rate)).rounded()), "crossovers": doubles(scene.driverCrossovers),
                "channels": result.channels.map(floats),
            ])
        }
        try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys]).write(
            to: output.appendingPathComponent("application.json"))
        print("PASS \(records.count) complete application FFT adoption records")
    }
}
