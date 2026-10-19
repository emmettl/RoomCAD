import AuditionDSP
import AVFoundation
import Foundation

// MARK: - Files

public enum DryClipError: LocalizedError {
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let message): message
        }
    }
}

extension DryClip {
    /// Reads any audio file Core Audio can decode, mixes it to mono and converts it to `sampleRate`.
    /// Files longer than `maximumDuration` are cut.
    public static func load(
        contentsOf url: URL, sampleRate: Int, id: String? = nil, name: String? = nil,
        credit: String = "Your file"
    ) throws -> DryClip {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw DryClipError.unreadable("\(url.lastPathComponent) is not an audio file RoomCAD can read.")
        }
        let format = file.processingFormat
        let frames = AVAudioFrameCount(min(Double(file.length), maximumDuration * format.sampleRate))
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw DryClipError.unreadable("\(url.lastPathComponent) contains no audio.")
        }
        try file.read(into: buffer, frameCount: frames)
        guard let channels = buffer.floatChannelData else {
            throw DryClipError.unreadable("\(url.lastPathComponent) could not be decoded to floating point.")
        }
        let count = Int(buffer.frameLength)
        let channelCount = Int(format.channelCount)
        var mono = [Float](repeating: 0, count: count)
        for c in 0..<channelCount {
            for i in 0..<count { mono[i] += channels[c][i] / Float(channelCount) }
        }
        let converted = try resample(mono, from: format.sampleRate, to: Double(sampleRate))
        return DryClip(
            id: id ?? url.absoluteString, name: name ?? url.deletingPathExtension().lastPathComponent,
            credit: credit, samples: converted, sampleRate: sampleRate)
    }

    /// Band-limited sample-rate conversion by Core Audio.
    static func resample(_ samples: [Float], from source: Double, to target: Double) throws -> [Float] {
        guard source != target else { return samples }
        guard let input = AVAudioFormat(standardFormatWithSampleRate: source, channels: 1),
            let output = AVAudioFormat(standardFormatWithSampleRate: target, channels: 1),
            let converter = AVAudioConverter(from: input, to: output),
            let inBuffer = AVAudioPCMBuffer(
                pcmFormat: input, frameCapacity: AVAudioFrameCount(samples.count)),
            let outBuffer = AVAudioPCMBuffer(
                pcmFormat: output,
                frameCapacity: AVAudioFrameCount(Double(samples.count) * target / source) + 1024)
        else { throw DryClipError.unreadable("Could not convert the sample rate.") }
        converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
        inBuffer.frameLength = inBuffer.frameCapacity
        samples.withUnsafeBufferPointer {
            inBuffer.floatChannelData![0].update(from: $0.baseAddress!, count: $0.count)
        }
        nonisolated(unsafe) var supplied = false
        nonisolated(unsafe) let source = inBuffer
        var error: NSError?
        let status = converter.convert(to: outBuffer, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .endOfStream
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return source
        }
        guard status != .error else {
            throw DryClipError.unreadable(
                "Could not convert the sample rate: \(error?.localizedDescription ?? "").")
        }
        return Array(
            UnsafeBufferPointer(start: outBuffer.floatChannelData![0], count: Int(outBuffer.frameLength)))
    }
}

// MARK: - Bundled recordings

extension DryClip {
    struct Entry: Codable {
        var id: String
        var name: String
        var file: String
        var credit: String
    }

    /// SwiftPM's resource bundle for this module. Found without `Bundle.module`, which traps when an app
    /// was packaged without the bundle; then there are simply no bundled clips.
    static var resources: Bundle? {
        let name = "RoomCAD_Audition.bundle"
        let candidates = [
            Bundle.main.resourceURL, Bundle.main.bundleURL,
            Bundle.main.executableURL?.deletingLastPathComponent(),
            // In tests, beside the test bundle.
            Bundle(for: BundleMarker.self).bundleURL.deletingLastPathComponent(),
        ]
        return candidates.compactMap { $0 }.lazy.compactMap { Bundle(url: $0.appendingPathComponent(name)) }
            .first
    }

    /// The recordings shipped with RoomCAD, listed in `Clips/clips.json`, at `sampleRate`.
    public static func bundled(sampleRate: Int) -> [DryClip] {
        guard let folder = resources?.url(forResource: "Clips", withExtension: nil),
            let data = try? Data(contentsOf: folder.appendingPathComponent("clips.json")),
            let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries.compactMap { entry in
            try? load(
                contentsOf: folder.appendingPathComponent(entry.file), sampleRate: sampleRate, id: entry.id,
                name: entry.name, credit: entry.credit)
        }
    }

    /// Bundled recordings followed by the generated test signals.
    public static func library(sampleRate: Int) -> [DryClip] {
        bundled(sampleRate: sampleRate) + [
            noiseBurst(sampleRate: sampleRate), clicks(sampleRate: sampleRate),
        ]
    }
}

private final class BundleMarker {}
