# Shared real FFT adoption

ContinuumKit alpha.17 is published from e94d329c55495ca561306174d624eadf5c8e7da0,
with independent DFT/inverse, packing, normalization, weighted sums, filtering,
convolution and safety contracts. RoomCAD's candidate replaces local vDSP arithmetic
with a small `SpectralTransforms` compatibility boundary. Existing application API
signatures, serial setup ownership, callback order, padding defaults and finite
supported outputs remain the same. Nonthrowing callers retain a failing precondition
for unsupported requests; recovery policy is not silently replaced by empty audio.
The shared API exposes its checked failures directly to independent callers.

Band selection, absorption, fitting, calibration, response identities, wave policy,
preview scheduling and resampling remain application responsibilities. Every other
AcousticCore/Audition source byte matches protected RoomCAD 2bc11ed6. Pre-existing
shared CAD, response and wave module sources also match alpha.12 exactly. The wave
and thin-probe fixtures now pin alpha.17; their independent verifiers retain only
the exact published alpha.12/alpha.17 version/revision pairs for historical replay.
Their numerical assertions are unchanged.

The [complete application fixture](../../Fixtures/FFTAdoptionBenchmark/README.md)
compiles identically against protected original and current packages, retaining
whole native arrays and inputs for all selected cases. Full application, physical
Metal, packaging/signature/headless snapshot and existing CPU/Metal wave and thin
probe checks remain required before adoption. The accepted candidate checkpoint is recorded below.
Previous acoustic reference identities and measured fixtures are unchanged.

## Accepted application checkpoint

Comparison source `6c176e6d6dc40faaa1da49cdb1804c3f4bfbe305` passes all 84
complete original/shared cases on both physical Macs: 12,778,605 native values
in 51,455,392 bytes per variant, all byte-identical. Independent complete decay,
sparse convolution and preview/mix references pass; ten paired corruption controls
reject. The earlier valid 199cb0d output is identical.

Both application checks pass 192 tests, actual Metal, optimized packaging/deep
strict signature and inspected headless snapshots. Their sources (local 1315c4f,
mini c447239) have the exact same Package/Sources/Tests bytes as accepted 6c176e6.
Both hosts also pass complete CPU/Metal production and thin-probe comparisons with
generator/saved WAV/metadata and native oracle controls.

The [initial mini workflow](https://github.com/emmettl/RoomCAD/actions/runs/38067568500)
is recorded as failed: its four required application/wave jobs succeed, while
its comparison fixture hits the unchanged scene-coordinate validator. The
[corrected comparison workflow](https://github.com/emmettl/RoomCAD/actions/runs/38068004663)
succeeds. Initial ray-count and source-coordinate setup failures, partial exports
and source phases remain in the complete private evidence archive.
[Verification identities](shared-real-fft-verification.json) preserve actual
producer/job scopes. Existing numerical bounds and measured fixtures are unchanged.

## Legacy reference compile boundary

After application adoption, masked/cylinder/admittance/absorbing-cylinder/tilted-pulse
reference consumers still pin their original pre-alpha.17 Core revisions. Copying
the current FFT shim into those verification modules cannot resolve its newer
product. Their preparation now reconstructs only the protected original FFT compile
control, alongside existing protected wave controls. Actual application source and
alpha.17 pins remain unchanged. Original numerical cases, golden identities and
frozen Core pins are preserved; current FFT application conformance is separate.
The original missing-module build diagnostic is retained. The copier rejects
production destinations, and ongoing provenance checks verify immutable Git/blob/
SHA identities. See [the control](../../Fixtures/OriginalFFTReference/README.md).

The reference compatibility candidate `6ca9378` passes four provenance tests
and all five affected CPU/Metal suites on both physical Macs, preserving 42 records
per backend/84 per host and every original pin/case/golden. The
[physical mini workflow](https://github.com/emmettl/RoomCAD/actions/runs/38069818869)
succeeds. [Exact scope](fft-reference-verification.json) retains identities;
complete native reports and the initial compile failure remain archived.

The subsequent full main run [38070744422](https://github.com/emmettl/RoomCAD/actions/runs/38070744422)
passes the application and nine acoustic jobs but exposes the same missing FFT
compile dependency in the frozen extrusion consumer. A separate verification-only
repair binds the same protected control without changing production source/pins,
reference cases or assertions. Producer `1a2bdfb559950b1ed2cb4d61d80b50e986cfa0d9`
passes all 36 strict plan/mesh layouts on both physical Macs, with identical full
records, zero assignment gaps and no unresolved boundary fallback. The
[bounded mini run](https://github.com/emmettl/RoomCAD/actions/runs/38074674602) succeeds;
[scope and identity](extrusion-fft-reference-verification.json) preserve the distinction
between the failed full-main run and the repaired bounded geometry gate.
