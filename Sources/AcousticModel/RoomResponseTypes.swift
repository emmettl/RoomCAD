import Foundation
import ImpulseResponseKit
import Synchronization
import simd

/// A point in the room with a stable identity.
public struct RoomPoint: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    /// Position in metres from the room's west, south, floor corner.
    public var position: SIMD3<Double>
    /// For receivers, the microphone; nil is omni, as in documents saved before microphones existed.
    public var microphone: Microphone?

    public init(id: UUID = UUID(), name: String, position: SIMD3<Double>, microphone: Microphone? = nil) {
        self.id = id
        self.name = name
        self.position = position
        self.microphone = microphone
    }
}

/// Everything needed to reproduce a room response.
public struct RoomResponseSettings: Codable, Equatable, Sendable {
    public var room: ShoeboxRoom
    /// An omnidirectional point source.
    public var source: RoomPoint
    /// Omnidirectional point receivers, one output channel each. Two receivers give a mono-to-stereo
    /// response.
    public var receivers: [RoomPoint]
    public var atmosphere: Atmosphere
    public var airAbsorption: Bool
    public var sampleRate: Int
    /// Arrivals later than this many seconds after emission are omitted.
    public var duration: Double
    /// Reflections above this order are omitted; see `RoomResponseDiagnostics.orderLimitedAfter`.
    public var maximumReflectionOrder: Int
    public var content: ResponseMetadata.Content
    /// Content above this frequency in Hz is kept and content below half of it removed; 0 keeps the raw
    /// model. Because every reflection is
    /// modelled as real and positive, the raw response accumulates a slowly decaying offset below the
    /// lowest room mode that is outside the usable band and would offset a convolution reverb.
    public var lowFrequencyCutoff: Double
    /// The most rays traced from the source for the scattered energy; fewer are traced in rooms where
    /// fewer suffice. Unused if no surface scatters.
    public var diffuseRays: Int
    /// Seed for the ray directions and the diffuse tail's random detail, so a response can be reproduced.
    public var randomSeed: UInt64
    /// Use the wave solver below the crossover, for room modes the geometrical model only approximates.
    public var lowFrequencyModel: Bool
    /// Crossover between the wave solver and the geometrical model in Hz; nil chooses it from the room.
    public var crossoverFrequency: Double?
    /// Open areas in the room's surfaces, through which sound leaves.
    public var openings: [Opening]

    /// Upper bound on the estimated number of image sources per receiver.
    public static let maximumImageCount = 40_000_000
    /// Closest permitted approach of a receiver to the source.
    public static let minimumSeparation = 0.05

    public init(
        room: ShoeboxRoom, source: RoomPoint, receivers: [RoomPoint], atmosphere: Atmosphere = .standard,
        airAbsorption: Bool = true, sampleRate: Int = 48_000, duration: Double = 1,
        maximumReflectionOrder: Int = 60, content: ResponseMetadata.Content = .complete,
        lowFrequencyCutoff: Double = 20, diffuseRays: Int = 40_000, randomSeed: UInt64 = 1,
        lowFrequencyModel: Bool = false, crossoverFrequency: Double? = nil, openings: [Opening] = []
    ) {
        self.room = room
        self.source = source
        self.receivers = receivers
        self.atmosphere = atmosphere
        self.airAbsorption = airAbsorption
        self.sampleRate = sampleRate
        self.duration = duration
        self.maximumReflectionOrder = maximumReflectionOrder
        self.content = content
        self.lowFrequencyCutoff = lowFrequencyCutoff
        self.diffuseRays = diffuseRays
        self.randomSeed = randomSeed
        self.lowFrequencyModel = lowFrequencyModel
        self.crossoverFrequency = crossoverFrequency
        self.openings = openings
    }

    package enum CodingKeys: String, CodingKey {
        case room, source, receivers, atmosphere, airAbsorption, sampleRate, duration, maximumReflectionOrder
        case content, lowFrequencyCutoff, diffuseRays, randomSeed, lowFrequencyModel, crossoverFrequency,
            openings
    }

    /// Settings saved before scattering existed decode with its defaults.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            room: try c.decode(ShoeboxRoom.self, forKey: .room),
            source: try c.decode(RoomPoint.self, forKey: .source),
            receivers: try c.decode([RoomPoint].self, forKey: .receivers),
            atmosphere: try c.decode(Atmosphere.self, forKey: .atmosphere),
            airAbsorption: try c.decode(Bool.self, forKey: .airAbsorption),
            sampleRate: try c.decode(Int.self, forKey: .sampleRate),
            duration: try c.decode(Double.self, forKey: .duration),
            maximumReflectionOrder: try c.decode(Int.self, forKey: .maximumReflectionOrder),
            content: try c.decode(ResponseMetadata.Content.self, forKey: .content),
            lowFrequencyCutoff: try c.decode(Double.self, forKey: .lowFrequencyCutoff),
            diffuseRays: try c.decodeIfPresent(Int.self, forKey: .diffuseRays) ?? 40_000,
            randomSeed: try c.decodeIfPresent(UInt64.self, forKey: .randomSeed) ?? 1,
            lowFrequencyModel: try c.decodeIfPresent(Bool.self, forKey: .lowFrequencyModel) ?? false,
            crossoverFrequency: try c.decodeIfPresent(Double.self, forKey: .crossoverFrequency),
            openings: try c.decodeIfPresent([Opening].self, forKey: .openings) ?? [])
    }

    /// Estimated image sources per receiver within the duration and order limits.
    public var estimatedImageCount: Double {
        let reach = duration * atmosphere.soundSpeed
        let withinReach = 4 / 3 * Double.pi * reach * reach * reach / room.volume
        let order = Double(maximumReflectionOrder)
        let withinOrder = 4 / 3 * order * order * order + 2 * order * order + 8 / 3 * order + 1
        return min(withinReach, withinOrder)
    }

    public func validate() throws {
        try room.validate()
        try atmosphere.validate()
        guard (8_000...384_000).contains(sampleRate) else {
            throw AcousticError.invalid("The sample rate must be between 8 kHz and 384 kHz.")
        }
        guard duration.isFinite, duration > 0, duration <= 30 else {
            throw AcousticError.invalid("The duration must be between 0 and 30 seconds.")
        }
        guard lowFrequencyCutoff == 0 || (5...200).contains(lowFrequencyCutoff) else {
            throw AcousticError.invalid("The low-frequency cutoff must be 0 (off) or between 5 and 200 Hz.")
        }
        if let crossoverFrequency, !(40...500).contains(crossoverFrequency) {
            throw AcousticError.invalid("The crossover must be between 40 and 500 Hz.")
        }
        guard (1_000...1_000_000).contains(diffuseRays) else {
            throw AcousticError.invalid("The number of diffuse rays must be between 1,000 and 1,000,000.")
        }
        guard (0...1_000).contains(maximumReflectionOrder) else {
            throw AcousticError.invalid("The maximum reflection order must be between 0 and 1000.")
        }
        guard (1...16).contains(receivers.count) else {
            throw AcousticError.invalid("A response needs between 1 and 16 receivers.")
        }
        for receiver in receivers { try receiver.microphone?.validate() }
        if room.mesh != nil, !openings.isEmpty {
            throw AcousticError.invalid("A room with a mesh has open faces instead of openings.")
        }
        for opening in openings { try opening.validate(in: room) }
        for point in [source] + receivers where !room.contains(point.position) {
            throw AcousticError.invalid("\(point.name) is not inside the room.")
        }
        for receiver in receivers
        where simd_distance(receiver.position, source.position) < Self.minimumSeparation {
            throw AcousticError.invalid(
                "\(receiver.name) must be at least \(Self.minimumSeparation) m from the source.")
        }
        guard room.plan != nil || estimatedImageCount <= Double(Self.maximumImageCount) else {
            throw AcousticError.invalid(
                "About \(Int(estimatedImageCount)) image sources per receiver; shorten the duration or "
                    + "lower the maximum reflection order.")
        }
    }
}

/// Measured facts about a generated response, saved beside it.
public struct RoomResponseDiagnostics: Codable, Equatable, Sendable {
    public var soundSpeed: Double
    public var bandCentres: [Double]
    /// Per receiver: arrivals rendered.
    public var arrivals: [Int]
    /// Per receiver: direct-path delay in seconds.
    public var directDelay: [Double]
    /// Per receiver: time in seconds after which reflections above the maximum order are missing, or
    /// nil if the order limit removed nothing within the duration.
    public var orderLimitedAfter: [Double?]
    /// Statistical estimates per band, for comparison; not measured from the response.
    public var sabineReverberationTime: [Double?]
    public var eyringReverberationTime: [Double?]
    /// `2000 sqrt(T/V)` with the mean Sabine time of the 500 Hz and 1 kHz bands. Below it, room modes are
    /// sparse and the geometrical model is approximate.
    public var schroederFrequency: Double?
    public var generationSeconds: Double
    /// Per receiver: the fraction of the response's energy from 500 Hz to 4 kHz that the ray tracer
    /// carried: scattered at least once, or specular beyond the order limit. Nil for responses made before
    /// scattering was modelled.
    public var scatteredFraction: [Double]?
    /// Rays traced for the scattered energy; zero when no surface scatters.
    public var diffuseRays: Int?
    /// Crossover to the wave solver in Hz, if it was used.
    public var waveCrossover: Double?
    /// The wave solver's grid cells and the time it took, if it was used.
    public var waveCells: Int?
    public var waveSeconds: Double?
    /// How many runs the walls' frequency-dependent absorption needed, and how many of them used the GPU;
    /// the rest ran on the CPU, because there was no GPU or other work was keeping it busy.
    public var waveRuns: Int?
    public var waveGPURuns: Int?
    /// For each octave band the wave solver covers, its room-averaged T30 before its decay was matched to
    /// Eyring's estimate (see `WaveSolver.responses`); nil for other bands.
    public var waveBareDecay: [Double?]?
    /// The wave solver's largest phase-velocity error at the crossover, over directions (negative: waves
    /// travel slower than sound); its modes are low by about as much. See `WaveAccuracy`.
    public var waveDispersion: Double?
    /// About how much memory the wave solver's grid took, in bytes.
    public var waveMemory: Int?
    /// Preview or full quality; nil for responses made before there were previews, which were full.
    public var quality: GenerationQuality?
    /// Why the wave solver was not used although asked for, if so.
    public var waveNote: String?
    /// In a room with a floor plan, the wall reflections and total reflections the image sources reached.
    public var planWallOrder: Int?
    public var planTotalOrder: Int?
    package init(soundSpeed: Double, bandCentres: [Double], arrivals: [Int], directDelay: [Double], orderLimitedAfter: [Double?], sabineReverberationTime: [Double?], eyringReverberationTime: [Double?], schroederFrequency: Double?, generationSeconds: Double, scatteredFraction: [Double]?, diffuseRays: Int?, waveCrossover: Double?, waveCells: Int?, waveSeconds: Double?, waveRuns: Int?, waveGPURuns: Int?, waveBareDecay: [Double?]?, waveDispersion: Double?, waveMemory: Int?, quality: GenerationQuality?, waveNote: String?, planWallOrder: Int?, planTotalOrder: Int?) {
        self.soundSpeed = soundSpeed
        self.bandCentres = bandCentres
        self.arrivals = arrivals
        self.directDelay = directDelay
        self.orderLimitedAfter = orderLimitedAfter
        self.sabineReverberationTime = sabineReverberationTime
        self.eyringReverberationTime = eyringReverberationTime
        self.schroederFrequency = schroederFrequency
        self.generationSeconds = generationSeconds
        self.scatteredFraction = scatteredFraction
        self.diffuseRays = diffuseRays
        self.waveCrossover = waveCrossover
        self.waveCells = waveCells
        self.waveSeconds = waveSeconds
        self.waveRuns = waveRuns
        self.waveGPURuns = waveGPURuns
        self.waveBareDecay = waveBareDecay
        self.waveDispersion = waveDispersion
        self.waveMemory = waveMemory
        self.quality = quality
        self.waveNote = waveNote
        self.planWallOrder = planWallOrder
        self.planTotalOrder = planTotalOrder
    }

}

/// A generated response together with the settings that produced it.
public struct RoomResponse: Sendable {
    public var response: ImpulseResponse
    public var settings: RoomResponseSettings
    public var diagnostics: RoomResponseDiagnostics

    public static let generatorName = "RoomCAD hybrid model 7"
    /// Generators whose saved responses can still be read; only the current one is up to date.
    public static let readableGenerators: Set<String> = [
        "RoomCAD image-source model 1", "RoomCAD hybrid model 2", "RoomCAD hybrid model 3",
        "RoomCAD hybrid model 4", "RoomCAD hybrid model 5", "RoomCAD hybrid model 6",
        generatorName,
    ]

    public static let assumptions = [
        "Rectangular room. Specular reflections by the image-source method; energy scattered at least once by "
            + "ray tracing with Lambert (cosine) reflection, rendered as a dense random reflection pattern with "
            + "that energy envelope. No diffraction.",
        "Each reflection keeps (1 - alpha) of the energy, of which a fraction s (the scattering coefficient) "
            + "leaves diffusely and the rest specularly.",
        "Specular pressure reflection coefficient sqrt((1 - alpha)(1 - s)) per octave band, real and positive "
            + "(no phase shift), independent of the angle of incidence.",
        "Absorption and air attenuation blend smoothly between octave-band centres; air attenuation uses "
            + "ISO 9613-1 at each band centre, so it is underestimated above about 11 kHz.",
        "Omnidirectional point source; receivers omnidirectional or ideal first-order microphones.",
        "Optionally, below a crossover, a finite-difference wave solver replaces the geometrical model, with "
            + "locally reacting walls of real impedance from each octave band's absorption, one run per group "
            + "of bands with the same impedances.",
        "Arrivals after the duration are omitted. Specular reflections above the maximum order are carried "
            + "by the ray tracer as an energy envelope.",
        "Zero-phase band filters can spread small pre-echoes ahead of an arrival whose band gains differ.",
        "A zero-phase high-pass at the low-frequency cutoff, if set, removes the sub-audio offset that real, "
            + "positive reflection coefficients accumulate.",
    ]

    /// Writes the response as WAV with a JSON description that includes these settings and diagnostics.
    public func write(wav url: URL) throws {
        try response.write(wav: url, generatorDetails: Details(settings: settings, diagnostics: diagnostics))
    }

    /// What a response's JSON description stores under `generatorDetails`.
    public struct Details: Codable, Sendable {
        public var settings: RoomResponseSettings
        public var diagnostics: RoomResponseDiagnostics

        public init(settings: RoomResponseSettings, diagnostics: RoomResponseDiagnostics) {
            self.settings = settings
            self.diagnostics = diagnostics
        }
    }

    public init(
        response: ImpulseResponse, settings: RoomResponseSettings, diagnostics: RoomResponseDiagnostics
    ) {
        self.response = response
        self.settings = settings
        self.diagnostics = diagnostics
    }

    /// WAV and JSON data as `write(wav:)` stores them.
    public func encoded() throws -> (wav: Data, metadata: Data) {
        try response.encoded(generatorDetails: Details(settings: settings, diagnostics: diagnostics))
    }

    /// Decodes data from `encoded()`, rejecting responses from another generator.
    public init(wav: Data, metadata: Data) throws {
        let response = try ImpulseResponse(wav: wav, metadata: metadata)
        guard Self.readableGenerators.contains(response.metadata.generator),
            let details = try ImpulseResponse.generatorDetails(Details.self, from: metadata)
        else {
            throw AcousticError.invalid("The response was not generated by RoomCAD.")
        }
        guard details.settings.receivers.count == response.channels.count,
            details.settings.sampleRate == response.sampleRate
        else {
            throw AcousticError.invalid("The response does not match its recorded settings.")
        }
        self.init(response: response, settings: details.settings, diagnostics: details.diagnostics)
    }
}

public enum GenerationQuality: String, Codable, Sendable {
    /// For export and listening: the wave solver's full budget and all the rays.
    case full
    /// For quick updates while a room is edited: a quarter of the wave solver's budget, which lowers its
    /// crossover by about a sixth, and a quarter of the rays, which leaves more noise in the scattered
    /// energy.
    case preview
}

/// What a generation is doing and how far it has got, for showing progress; any thread may read it.
public final class GenerationProgress: @unchecked Sendable {
    public enum Stage: String, Sendable, CaseIterable {
        case rays = "Tracing rays"
        case reflections = "Rendering reflections"
        case waveSolver = "Wave solver"
    }

    private let lock = NSLock()
    private var stage: Stage?
    private var fraction = 0.0

    public init() {}

    /// The stage under way, if any, and the fraction of it done, from 0 to 1.
    public var current: (stage: Stage?, fraction: Double) { lock.withLock { (stage, fraction) } }

    package func begin(_ stage: Stage) { lock.withLock { (self.stage, fraction) = (stage, 0) } }

    package func advance(by amount: Double) { lock.withLock { fraction = min(fraction + amount, 1) } }
}

/// A cancellation request that worker threads can see.
public final class CancellationFlag: Sendable {
    private let state = Atomic<Bool>(false)

    public init() {}

    public func cancel() { state.store(true, ordering: .relaxed) }

    public var isCancelled: Bool { state.load(ordering: .relaxed) }
}

