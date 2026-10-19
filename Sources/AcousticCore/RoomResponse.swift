import AcousticModel
import Foundation
import ImpulseResponseKit
import Synchronization
import simd

public enum RoomResponseGenerator {
    /// Generates one channel per receiver: the room's response to an impulse emitted by the source at
    /// frame 0, as pressure relative to the free-field pressure 1 m from the source.
    ///
    /// The work runs on several cores. Throws `CancellationError` if the calling task is cancelled.
    public static func generate(
        _ settings: RoomResponseSettings, quality: GenerationQuality = .full,
        progress: GenerationProgress? = nil
    ) async throws -> RoomResponse {
        let flag = CancellationFlag()
        return try await withTaskCancellationHandler {
            try generate(settings, cancellation: flag, quality: quality, progress: progress)
        } onCancel: {
            flag.cancel()
        }
    }

    /// The diffuse tail's seed for one receiver, from its identity, so its channel does not change when
    /// other receivers are added, removed or reordered.
    static func tailSeed(_ seed: UInt64, receiver: UUID) -> UInt64 {
        var mix = SplitMix(seed: seed)
        var value = mix.next()
        withUnsafeBytes(of: receiver.uuid) { bytes in
            for byte in bytes {
                mix = SplitMix(seed: value ^ UInt64(byte))
                value = mix.next()
            }
        }
        return value
    }

    /// Generates synchronously; `cancellation`, or cancelling the calling task, stops it.
    public static func generate(
        _ settings: RoomResponseSettings, cancellation: CancellationFlag = CancellationFlag(),
        quality: GenerationQuality = .full, progress: GenerationProgress? = nil
    ) throws -> RoomResponse {
        try generate(
            settings, cancellation: cancellation, quality: quality, progress: progress,
            configureWaveSolver: { $0 })
    }

    /// Internal complete-generator comparison seam; the public path retains identity configuration.
    static func generate(
        _ settings: RoomResponseSettings, cancellation: CancellationFlag = CancellationFlag(),
        quality: GenerationQuality = .full, progress: GenerationProgress? = nil,
        configureWaveSolver: (WaveSolver) -> WaveSolver
    ) throws -> RoomResponse {
        try settings.validate()
        let start = Date()
        // Worker threads cannot see the task, so the calling thread passes its cancellation on.
        let cancelled: @Sendable () -> Bool = {
            if Task.isCancelled { cancellation.cancel() }
            return cancellation.isCancelled
        }
        func check() throws { if cancelled() { throw CancellationError() } }
        // Image sources and statistical estimates treat openings as absorption; rays and the wave solver
        // place them exactly.
        let effectiveRoom = settings.room.withOpenings(settings.openings)
        let model = ImageSourceModel(
            room: effectiveRoom, source: settings.source.position, atmosphere: settings.atmosphere,
            airAbsorption: settings.airAbsorption)
        let frames = Int((settings.duration * Double(settings.sampleRate)).rounded(.up))
        let includeDirect = settings.content == .complete
        var tracer = DiffuseRayTracer(
            room: settings.room, source: settings.source.position, atmosphere: settings.atmosphere,
            airAbsorption: settings.airAbsorption,
            rayCount: quality == .preview ? settings.diffuseRays / 4 : settings.diffuseRays,
            seed: settings.randomSeed)
        tracer.openings = settings.openings
        // A floor plan's image sources reach the wall order that fits their budget, and a few floor and
        // ceiling reflections beyond; rays carry every other specular path.
        let reach = settings.duration * settings.atmosphere.soundSpeed
        let planImages: (images: [PlanImageSources.Image], wallOrder: Int, totalOrder: Int)?
        if let plan = effectiveRoom.plan {
            let generated = PlanImageSources(
                room: effectiveRoom, plan: plan, source: settings.source.position
            )
            .images(maximumOrder: settings.maximumReflectionOrder, reach: reach)
            let total = min(
                settings.maximumReflectionOrder, generated.order + PlanImageSources.verticalAllowance)
            planImages = (generated.images, generated.order, total)
            tracer.specularWallLimit = generated.order
            tracer.specularOrderLimit = total
        } else {
            planImages = nil
        }
        // A mesh's image sources reach the order that fits their budget; rays carry every specular path
        // beyond it.
        let meshImages: (images: [MeshImageSources.Image], order: Int)?
        if let mesh = effectiveRoom.mesh {
            let generated = MeshImageSources(geometry: .of(mesh), source: settings.source.position)
                .images(maximumOrder: settings.maximumReflectionOrder, reach: reach)
            meshImages = generated
            tracer.specularOrderLimit = generated.order
        } else {
            meshImages = nil
        }
        // Where the order limit may omit specular reflections within the duration, rays carry them on.
        if planImages == nil, meshImages == nil,
            Double(settings.maximumReflectionOrder) * settings.room.size.min() < settings.duration
                * settings.atmosphere.soundSpeed
        {
            tracer.specularOrderLimit = settings.maximumReflectionOrder
        }
        progress?.begin(.rays)
        let diffuse = tracer.trace(
            receivers: settings.receivers.map { ($0.position, $0.microphone ?? .omni) },
            duration: settings.duration,
            stop: cancelled, progress: progress)
        try check()
        // The bands whose energy the scattered fraction reports, 500 Hz to 4 kHz.
        let reported = 3...6

        // Receivers are independent, so each renders on its own core.
        struct Channel {
            var samples: [Float]
            var arrivals: Int
            var orderLimitedAfter: Double?
            var scatteredFraction: Double
        }
        let results = ChunkResults<Channel>(count: settings.receivers.count)
        progress?.begin(.reflections)
        DispatchQueue.concurrentPerform(iterations: settings.receivers.count) { index in
            defer { progress?.advance(by: 1 / Double(settings.receivers.count)) }
            guard !cancelled() else { return }
            var renderer = BandRenderer(
                sampleRate: settings.sampleRate, frames: frames,
                lowFrequencyCutoff: settings.lowFrequencyCutoff)
            var specularEnergy = 0.0
            let receiver = settings.receivers[index]
            let add = { (delay: Double, _: Int, gains: [Double]) in
                renderer.add(delay: delay, gains: gains)
                for b in reported { specularEnergy += gains[b] * gains[b] }
            }
            let summary =
                if let meshImages {
                    model.forEachMeshArrival(
                        at: receiver.position, images: meshImages.images, order: meshImages.order,
                        microphone: receiver.microphone ?? .omni, duration: settings.duration,
                        maximumOrder: settings.maximumReflectionOrder, includeDirect: includeDirect,
                        stop: cancelled, add)
                } else if let planImages {
                    model.forEachPlanArrival(
                        at: receiver.position, images: planImages.images, wallOrder: planImages.wallOrder,
                        microphone: receiver.microphone ?? .omni, duration: settings.duration,
                        maximumOrder: planImages.totalOrder, includeDirect: includeDirect, stop: cancelled,
                        add)
                } else {
                    model.forEachArrival(
                        at: receiver.position, microphone: receiver.microphone ?? .omni,
                        duration: settings.duration,
                        maximumOrder: settings.maximumReflectionOrder, includeDirect: includeDirect,
                        stop: cancelled,
                        add)
                }
            guard !cancelled() else { return }
            let diffuseEnergy = DiffuseTail.render(
                diffuse[index], into: &renderer, roomVolume: settings.room.volume,
                soundSpeed: settings.atmosphere.soundSpeed,
                seed: Self.tailSeed(settings.randomSeed, receiver: settings.receivers[index].id),
                bands: reported,
                earliest: simd_distance(receiver.position, settings.source.position)
                    / settings.atmosphere.soundSpeed)
            let total = specularEnergy + diffuseEnergy
            results.store(
                Channel(
                    samples: renderer.render(), arrivals: summary.arrivals,
                    orderLimitedAfter: summary.orderLimitedAfter,
                    scatteredFraction: total > 0 ? diffuseEnergy / total : 0),
                at: index)
        }
        try check()
        let rendered = results.values
        var channels = rendered.map(\.samples)
        let arrivals = rendered.map(\.arrivals)
        let orderLimitedAfter = rendered.map(\.orderLimitedAfter)
        let scatteredFraction = rendered.map(\.scatteredFraction)

        let c = settings.atmosphere.soundSpeed
        let sabine = effectiveRoom.sabineReverberationTime(
            atmosphere: settings.atmosphere, airAbsorption: settings.airAbsorption)
        let eyring = effectiveRoom.eyringReverberationTime(
            atmosphere: settings.atmosphere, airAbsorption: settings.airAbsorption)
        var schroeder: Double?
        if let t500 = sabine[3], let t1000 = sabine[4] {
            schroeder = 2000 * ((t500 + t1000) / 2 / settings.room.volume).squareRoot()
        }

        // Below the crossover, replace the geometrical response with the wave solver's.
        var wave:
            (
                crossover: Double, cells: Int, seconds: Double, runs: Int, gpuRuns: Int, bareDecay: [Double?],
                dispersion: Double?, memory: Int
            )?
        var waveNote: String?
        if settings.lowFrequencyModel {
            let waveStart = Date()
            let fftLength = BandRenderer(sampleRate: settings.sampleRate, frames: frames).fftLength
            if let plan = WavePlan(
                settings: settings, schroeder: schroeder, fftLength: fftLength,
                budgetScale: quality == .preview ? 0.25 : 1)
            {
                let crossover = plan.crossover
                let cutoff = settings.lowFrequencyCutoff
                progress?.begin(.waveSolver)
                let configuredSolver = configureWaveSolver(plan.solver)
                let low = configuredSolver.responses(
                    source: settings.source.position,
                    receivers: settings.receivers.map { ($0.position, $0.microphone ?? .omni) },
                    frames: frames,
                    fftLength: fftLength, progress: progress,
                    weight: { f in
                        (1 - OctaveBands.rise(f, crossover: crossover))
                            * (cutoff > 0 ? OctaveBands.rise(f, crossover: cutoff / 2.squareRoot()) : 1)
                    }, stop: cancelled)
                try check()
                if let low {
                    for index in channels.indices {
                        let high = RealFFT.zeroPhaseFilter(
                            channels[index], sampleRate: Double(settings.sampleRate)
                        ) {
                            OctaveBands.rise($0, crossover: crossover)
                        }
                        channels[index] = zip(high, low.channels[index]).map { $0 + $1 }
                    }
                    let cells = plan.solver.cells
                    wave = (
                        crossover, cells.x * cells.y * cells.z, Date().timeIntervalSince(waveStart),
                        plan.solver.bandGroups.count, low.gpuRuns,
                        OctaveBands.centres.indices.map { low.decay[$0]?.bare },
                        WaveAccuracy.worstPhaseVelocityError(
                            frequency: crossover, spacing: plan.solver.spacing,
                            timeStep: plan.solver.timeStep,
                            soundSpeed: c),
                        plan.solver.memoryEstimate
                    )
                }
            } else {
                waveNote = "The room is too large or the response too long for the wave solver's budget."
            }
        }
        let diagnostics = RoomResponseDiagnostics(
            soundSpeed: c, bandCentres: OctaveBands.centres, arrivals: arrivals,
            directDelay: settings.receivers.map { simd_distance($0.position, settings.source.position) / c },
            orderLimitedAfter: orderLimitedAfter, sabineReverberationTime: sabine,
            eyringReverberationTime: eyring, schroederFrequency: schroeder,
            generationSeconds: Date().timeIntervalSince(start), scatteredFraction: scatteredFraction,
            diffuseRays: settings.room.scatters || tracer.specularOrderLimit < Int.max
                ? tracer.tracedRays : 0, waveCrossover: wave?.crossover,
            waveCells: wave?.cells, waveSeconds: wave?.seconds, waveRuns: wave?.runs,
            waveGPURuns: wave?.gpuRuns, waveBareDecay: wave?.bareDecay, waveDispersion: wave?.dispersion,
            waveMemory: wave?.memory, quality: quality,
            waveNote: waveNote,
            planWallOrder: planImages?.wallOrder, planTotalOrder: planImages?.totalOrder ?? meshImages?.order)

        let metadata = ResponseMetadata(
            sampleRate: settings.sampleRate, frameCount: frames,
            channels: settings.receivers.map {
                .init(
                    name: $0.name, sourceID: settings.source.id, receiverID: $0.id,
                    receiverPosition: [$0.position.x, $0.position.y, $0.position.z],
                    directivity: $0.microphone.flatMap { $0.pattern == .omni ? nil : $0.summary })
            },
            content: settings.content,
            gainConvention:
                "Each arrival is a band-limited impulse whose samples sum to its sound pressure relative to "
                + "the free-field pressure 1 m from the source.",
            usableBand: .init(
                lowerHz: max(settings.lowFrequencyCutoff, 20),
                upperHz: BandRenderer.passbandFraction * Double(settings.sampleRate)),
            // With the wave solver, the low frequencies are modelled as waves, not approximated.
            approximateBelowHz: wave == nil ? schroeder : nil,
            model: (quality == .preview ? "Preview quality. " : "")
                + (wave.map {
                    String(
                        format:
                            "Finite-difference wave solver below %.0f Hz, with phase velocity within %.1f%% of the "
                            + "speed of sound there and its decay matched to Eyring's estimate in each band; above "
                            + "it, geometrical acoustics (image sources for specular paths, ray tracing for "
                            + "scattered energy).", $0.crossover, abs($0.dispersion ?? 0) * 100)
                }
                    ?? "Geometrical acoustics (image sources for specular paths, ray tracing for scattered energy); "
                    + "low-frequency behaviour is approximate."),
            assumptions: RoomResponse.assumptions, generator: RoomResponse.generatorName)
        return RoomResponse(
            response: try ImpulseResponse(channels: channels, metadata: metadata), settings: settings,
            diagnostics: diagnostics)
    }
}

/// How thoroughly a response is generated.
/// The wave solver's crossover and grid for a response, within a fixed amount of work.
struct WavePlan {
    let crossover: Double
    let solver: WaveSolver

    /// Cell updates allowed, counting every band group's run: a few seconds on the GPU or the CPU.
    static let gpuBudget = 1.5e10
    static let cpuBudget = 4e9

    /// Nil if even the lowest useful crossover is too much work.
    init?(
        settings: RoomResponseSettings, schroeder: Double?, fftLength: Int, budgetScale: Double = 1,
        solverFactory: ((Double) -> WaveSolver)? = nil
    ) {
        let span = Double(fftLength) / Double(settings.sampleRate)
        func solver(_ crossover: Double) -> WaveSolver {
            if let solverFactory { return solverFactory(crossover) }
            return WaveSolver(
                room: settings.room, sampleRate: settings.sampleRate,
                topFrequency: crossover * 2.squareRoot(),
                atmosphere: settings.atmosphere, openings: settings.openings)
        }
        func cost(_ solver: WaveSolver) -> Double {
            solver.cost(duration: span) * Double(solver.bandGroups.count)
        }
        if let chosen = settings.crossoverFrequency {
            crossover = chosen
            self.solver = solver(chosen)
            return
        }
        var candidate = solver(250)
        let gpu = candidate.usesGPU
        // A floor plan's masked grid costs about twice as much per cell on the CPU.
        let budget =
            budgetScale * (gpu ? Self.gpuBudget : Self.cpuBudget / (settings.room.plan == nil ? 1 : 2))
        // Three times the Schroeder frequency, where modes have become dense, within 80 to 500 Hz on the GPU
        // (250 Hz on the CPU).
        var f = min(max(3 * (schroeder ?? 125), 80), gpu ? 500 : 250)
        candidate = solver(f)
        // Work grows as the fourth power of frequency; lower the crossover until it fits.
        while cost(candidate) > budget {
            f *= 0.97 * pow(budget / cost(candidate), 0.25)
            guard f >= 60 else { return nil }
            candidate = solver(f)
        }
        crossover = f
        self.solver = candidate
    }
}
