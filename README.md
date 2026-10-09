# RoomCAD

Offline impulse responses of rooms, for convolution reverb: a macOS document app, the acoustic
model and response files. See the [roadmap](docs/roomcad-roadmap.md) for what is planned.

| Module | Contents |
|---|---|
| RoomCAD | The document app: plan and section drawings, inspector, generation, auditioning, WAV export |
| Audition | Dry clips (bundled, generated or chosen), FFT convolution previews and loudness matching |
| RoomDocument | The versioned `.roomcad` format and response summaries |
| AcousticCore | Rectangular rooms, octave-band materials, air absorption, image sources, rendering, decay analysis |
| ImpulseResponseKit (ContinuumKit) | Response metadata, 32-bit float WAV reading and writing, common-gain conditioning |
| acousticbench | Analytical checks and a reference room exported as stereo WAV |

```bash
swift run -c release RoomCAD
```

```bash
swift test
```

```bash
swift run -c release acousticbench --out roomcad-reference
```

The app and its documents are described in [RoomCAD app and documents](docs/roomcad-app.md),
and the model, its checks and its limitations in
[Room-acoustics model](docs/room-acoustics-model.md). The package pins public ContinuumKit `0.1.0-alpha.2` for its CAD foundations and response
interchange and depends on nothing in BombCAD. Third-party data and recordings are
credited in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

Build a Finder-launchable app with `make app`; run the full local checks with `make check`.
The dedicated physical Mac mini runs [CI](docs/CI.md). Source history is retained from
BombCAD; see [repository migration](docs/REPOSITORY_MIGRATION.md). Historical signed
0.1.0 downloads remain at the [original release](https://github.com/emmettl/bombcad/releases/tag/roomcad-v0.1.0).

Masked acoustic geometry contracts: [scope and checks](docs/benchmarks/MASKED_DOMAINS.md).
