# RoomCAD

Offline impulse responses of rooms, for convolution reverb: a macOS document app, the acoustic
model and response files. See the [roadmap](docs/roomcad-roadmap.md) for what is planned.

| Module | Contents |
|---|---|
| RoomCAD | The document app: plan and section drawings, inspector, generation, auditioning, WAV export |
| Audition | macOS recording decoding and the credited bundled clips |
| AuditionDSP | Portable generated clips, convolution previews, loudness matching and overviews |
| RoomDocument | The versioned `.roomcad` format and response summaries |
| AcousticModel | Portable geometry, materials, settings, response values and decay analysis |
| AcousticCore | Response generation, calibration, CPU waves and macOS Metal execution |
| ImpulseResponseKit (ContinuumKit) | Response metadata, 32-bit float WAV reading and writing, common-gain conditioning |
| acousticbench | Analytical checks and a reference room exported as stereo WAV |

Install the published macOS app (Apple Silicon, macOS 15 or later):

```bash
brew install --cask emmettl/tap/roomcad
```

The cask currently installs the historical notarized **0.1.0** release. Build from
source for the latest changes:

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
[Room-acoustics model](docs/room-acoustics-model.md). The package pins public ContinuumKit `0.1.0-alpha.30` for its CAD foundations, response
interchange, wave execution, FFT and fitting primitives, and depends on nothing in BombCAD. Third-party data and recordings are
credited in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

The model, CPU generator, document layer, audition DSP and CLI also build on Linux;
see [portable modules and verification](docs/PORTABILITY.md).

Build a Finder-launchable app with `make app`; run the full local checks with `make check`.
The dedicated physical Mac mini runs [CI](docs/CI.md). Source history is retained from
BombCAD; see [repository migration](docs/REPOSITORY_MIGRATION.md). Historical signed
0.1.0 downloads remain at the [original release](https://github.com/emmettl/bombcad/releases/tag/roomcad-v0.1.0).

Masked acoustic geometry contracts: [scope and checks](docs/benchmarks/MASKED_DOMAINS.md).
