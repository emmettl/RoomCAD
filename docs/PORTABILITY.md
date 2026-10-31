# Portable modules

RoomCAD pins ContinuumKit **0.1.0-alpha.29** exactly. Its Linux SIMD, Accelerate
and archive foundations make the application-owned CPU layers buildable without
Apple frameworks. This tag also contains SceneRender's viewport Tab-focus fix;
clicking the viewport can still make it first responder.

| Target | macOS | Linux | Responsibility |
|---|---|---|---|
| AcousticModel | Yes | Yes | Geometry, materials, settings, response values, FFT adapters and decay analysis |
| AcousticCore | Yes | CPU | Generation, rendering, calibration and wave execution |
| RoomDocument | Yes | Yes | Stable document and response interchange |
| AuditionDSP | Yes | Yes | Generated clips, convolution, level matching and waveform overviews |
| Audition | Yes | No | AVFoundation decoding and the existing credited recording bundle |
| acousticbench | Yes | Yes | Analytical checks and reference WAV export |
| RoomCAD | Yes | No | SwiftUI/AppKit editor, playback and Metal viewport |

`AcousticCore` re-exports `AcousticModel`, and `Audition` re-exports `AuditionDSP`,
so existing application imports continue to work. Package visibility exposes the
existing model implementation only to other targets in this package. These
application layers remain owned by RoomCAD; shared CAD and interchange code stays
in ContinuumKit. Document type, producer and generator identifiers are unchanged.

On Linux, run `swift build`, `swift test -c release` and
`swift run -c release acousticbench --out /tmp/roomcad-reference`. Release
optimization is useful for the CPU wave and fallback FFT workloads. The pinned Ubuntu Swift
container in `.github/workflows/linux.yml` runs these checks. Document round trips
use real package directories and the URL reader there; macOS still exercises
FileWrapper. Linux preset timing uses generated noise because AVFoundation and
the bundled recording decoder are unavailable. Linux excludes the three tests
that require actual Metal, while CPU generation and backend-failure tests run.

Linux floating-point results need not be bit-identical to Apple: libm and FFT
implementations can round differently. The existing numerical tolerances are
retained. `AcousticModel/LinuxSIMD.swift` adapts only the vector arithmetic and
double matrix multiplication and quaternion inverse needed from BombCAD's MIT-licensed implementation at
`a1a16aafd01f893ac9f9f7d059e0890ec526961e`, preserving its operation order and
fused cross products. The lexical split reader comes from the same revision's
`Scripts/split/swift_source.py`. Apple's native SIMD, Accelerate and Metal remain
active on macOS. ContinuumKit's quaternion-to-matrix stand-in is used on Linux;
its final bits can differ from Apple's implementation.

`Scripts/portable_source.py` binds every original acoustic declaration to committed
RoomCAD `9d532557afd7e2853044957c28c2cb6a30d27ec0`. It compares all Swift tokens,
including strings and numerical statements, allowing the recorded module imports,
package modifiers, four assignment-only constructors and the explicit Metal
availability guards. It also verifies audition DSP and document declarations.
Mutation tests reject changed density factors, constructor assignments, fitting
coordinates and saved generator identifiers.

Historical fixtures keep their exact tags, source snapshots and corruption
controls. Their single-module consumers first prove the current split and then
reconstruct equivalent pre-split macOS declarations for their frozen manifests.
The accepted alpha23 source gate is replayed in its committed checkout; the
current gate separately proves the split and byte-identical acoustic operators in
alpha29. Current production wave/probe consumers use alpha29 and include both
model and execution sources in their provenance. No measured fixture is rewritten.

Actual rendering, GPU wave parity, packaging and snapshots remain checks on the
physical Metal Mac mini. Heavy BRAS empirical validation remains `make validate`.
