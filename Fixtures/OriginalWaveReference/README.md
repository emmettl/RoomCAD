# Original masked CPU verification source

The production app has retired its duplicate masked CPU evolution/source/sampling
loop. Tests and current CPU/thin benchmark packages share one canonical file,
`Tests/AcousticCoreTests/OriginalMaskedCPU.swift`; benchmark source links point to
that same file. It is excluded from application product targets and uses the bare
app-owned backend protocol only for verification injection.

The complete original method is byte-identical to RoomCAD
`c47fdc889ef294571fa5683963e5892afe5e38ab:Sources/AcousticCore/WaveSolver.swift`.
`WaveSolver.swift.gz` is a deterministic, noncompiled snapshot of the full original
Git blob. The manifest records the compressed/uncompressed hashes, blob identity,
verbatim extension and canonical file hashes. The guard compares available original
Git data, and mini application CI requires the Git comparison rather than silently
using the snapshot alone. Independent corruption controls cover changed numerical
code even after its local hash is refreshed, payload corruption, wrong revision/blob,
misdirected/copied benchmark controls and missing required Git provenance.

Frozen source-free/geometry consumers reconstruct this source inside their copied
AcousticCore module, omitting only the self-module import. Their full original masked
fallback remains usable, while their numerical wrappers still bind the same verbatim
coefficients and update phases. Their existing dependency pins and independent
oracles are unchanged. App-owned geometry, pulse, receiver mapping and the separately
verified thin probe policy remain supplied by the current app.

The production masked CPU backend is mandatory and uses exact released Core alpha.12.
The optimized unmasked box CPU contract and original GPU resource/availability/fallback
code remain separate tasks. The packaged application gate requires shared backend
symbols and rejects any original masked CPU implementation symbol. This migration
changes ownership/location, not an acoustic law or a measured fixture. MIT attribution
is retained by the repository licence; no new application binary release is implied.

The [original GPU implementation is now retired](../../docs/benchmarks/RETIRED_ORIGINAL_METAL.md), with protected verification-only
reconstruction and selected-backend availability/planning. Missing shared context now
selects CPU directly; the old inline-GPU preparation fallback is retired. Both-host
output, full application and packaged exclusion gates pass; no new Core tag is needed.
