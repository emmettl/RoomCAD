# Shared masked CPU application default

The RoomCAD application product now selects Core alpha.9 for masked plan/mesh CPU
runs. The optimized unmasked box CPU and existing Metal production paths retain their
own contracts. Engine selection, crossover/cost budgets and automatic GPU abandonment
remain caller-owned. Shared simulation owns its fields/plans/output/lookahead per call,
retains the original 64-step cancellation cadence and original source scaling/mixing,
and uses serial work below 4,096 cells and min(z,16) synchronous slabs otherwise.

This follows complete independently verified Core forcing/receiver/execution gates,
exact-tag publication and app binding/generator/save/performance checks. The
[directional minimal-grid rule](THIN_DIRECTIONAL_PROBES.md) is now explicitly defined
and verified on CPU and actual original/Core Metal, closing the invalid minus-face
address that previously prevented default adoption.

`usingOriginalMaskedCPU()` explicitly clears the optional backend for retained-source
controls. Production uses `ROOMCAD_SHARED_WAVE_DEFAULT` in the app's AcousticCore
manifest. Older original reference consumers copy the same original source/geometry
into frozen manifests without that application build setting; they keep original
numerical evolution and original dependencies. This setting expresses the application
integration boundary; it is not a UI option or physics tuning parameter. The independent
oracles and pinned original update blocks stay unchanged. The old numeric method is
retained until both backend migrations allow a separate retirement task.

The optimized current-app producer now requires three complete variants: original,
explicit shared and actual application default. Every channel/value/bit/clock/layout
must agree, including full wave-enabled generator, non-timing diagnostics and actual
saved WAV/metadata. An additional negative control corrupts only the default to prove
it cannot be omitted or silently substituted. Root runtime tests also assert the
application default is SharedMaskedCPUSimulation and the explicit original is nil.
Frozen original masked source/reference checks remain active to verify the separate
manifest's compatibility. Numerical equivalence is not measured acoustic accuracy.

Full local/mini lint/tests, release-script checks, packaging/signature verification,
actual-Metal snapshot and complete current-app/three-way/thin source gates precede
merge. Retain clean producer metadata, exact alpha.9 dependency and all raw evidence.
Metal production/pipeline reuse, abandon/restart ownership and timed app acceptance
remain the next separate integration tranche. No app binary release is implied.

## Verified checkpoint

Producer `8737eb90e3b8c0f25f61d42002a7454cdb9d7487` passes the
[mini production gate](https://github.com/emmettl/RoomCAD/actions/runs/38023310728),
[thin CPU/actual-Metal gate](https://github.com/emmettl/RoomCAD/actions/runs/38022765847)
and [full application gate](https://github.com/emmettl/RoomCAD/actions/runs/38023574660).
All 72 three-way runs/36,696 samples per variant per host, complete generator outputs,
non-timing diagnostics and saved WAV bytes agree across M4 Max and M4, preserving the
earlier alpha.9 output. The thin gate retains 90 complete runs/45,144 samples per backend.
Ten production negative controls and fifteen focused tests pass. Full local and mini
checks pass 182 Swift tests, lint, eight Python release tests and compilation; mini
packaging/signature/snapshot checks pass, with the actual snapshot visually inspected.

All 39 tracked producer hashes match the tested commit on both hosts. Raw envelopes
may additionally contain ignored `.build` checkout hashes; those entries are retained
as cache provenance rather than treated as application source. The final checkpoint
changes documentation only. Full private raw reports/logs/source continuity evidence
are retained in Edgerton; [aggregate findings](shared-masked-cpu-default-verification.json)
are public.

The Max shared/original median wall ratios are 0.934/1.060/1.278; mini ratios are
1.080/1.106/1.133 on 3,888/29,610/331,800 cells. Shared certification retains a cost
absent from the old loop; preserve all repetitions and the live-host scope. No speedup
claim or automatic-engine/budget policy change accompanies this default switch.
