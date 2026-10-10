# Shared real FFT adoption candidate

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
probe checks remain required before adoption. Candidate preparation is not acceptance.
Previous acoustic reference identities and measured fixtures are unchanged.
