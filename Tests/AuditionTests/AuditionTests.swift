import Foundation
import ImpulseResponseKit
import Testing

@testable import Audition

@Suite("Recording decoding and library")
struct AuditionRecordingTests {
    @Test("Audio files are mixed to mono and converted to the response's rate")
    func loading() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("tone.wav")
        let tone = (0..<44_100).map { Float(sin(2 * Double.pi * 440 * Double($0) / 44_100)) * 0.25 }
        try WAVFile.encode(channels: [tone, tone.map { -$0 * 0.5 }], sampleRate: 44_100).write(to: url)
        let clip = try DryClip.load(contentsOf: url, sampleRate: 48_000)
        #expect(clip.name == "tone")
        #expect(abs(clip.samples.count - 48_000) < 100)
        #expect(abs(clip.samples.map(abs).max()! - DryClip.peak) < 1e-6)
        // Still a 440 Hz tone: count rising zero crossings in the middle second.
        let crossings = zip(clip.samples, clip.samples.dropFirst()).filter { $0 < 0 && $1 >= 0 }.count
        #expect(abs(crossings - 440) <= 2)

        let text = folder.appendingPathComponent("notes.wav")
        try Data("not audio".utf8).write(to: text)
        #expect(throws: DryClipError.self) { try DryClip.load(contentsOf: text, sampleRate: 48_000) }
    }
    @Test("The library offers the bundled recordings, then the test signals")
    func library() {
        #expect(DryClip.resources != nil)
        let clips = DryClip.library(sampleRate: 48_000)
        #expect(
            clips.map(\.id) == [
                "openair-operatic-voice", "iowa-violin-pizzicato", "openair-drums", "noise-burst", "clicks",
            ])
        for clip in clips.prefix(3) {
            #expect(!clip.credit.isEmpty)
            #expect(clip.sampleRate == 48_000)
            #expect(clip.duration > 4 && clip.duration < 12)
            #expect(abs(clip.samples.map(abs).max()! - DryClip.peak) < 1e-6)
        }
        // The 44.1 kHz pizzicato is converted, keeping its length.
        let pizzicato = clips.first { $0.id == "iowa-violin-pizzicato" }!
        #expect(abs(pizzicato.duration - 11.25) < 0.01)
    }
}
