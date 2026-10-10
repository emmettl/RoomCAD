# Optional production Metal comparison binding

Candidate: 10 October 2026. `WaveSolver.usingSharedMetal(context:)` selects a shared
GPU implementation explicitly; the original Metal backend remains the default. Root
application and current production consumer pin exact published Core alpha.10, commit
`da7cb5f5ac642edc57e8433c6150dceca6b9edd9`. The caller supplies one immutable
compiled device context, and each simulation owns its prepared grid/plans, queue,
fields, amplitude/readout storage, channels and aligner. No global cache or new UI.

The adapter reuses actual app layout/source/receiver preparation. Pulse midpoint
amplitudes and source scaling stay unchanged; Core retains original Float sampling
and axes. Application microphone pattern mixing uses the original Double order,
with one-frame lookahead across 128-step command boundaries and terminal half-step
fallback exactly once. Empty calls return empty channels without cancellation work.

Cancellation is checked before every command batch, including the first. After
synchronous completion and optional `gpuDelay`, only nonterminal batches call the
existing abandon callback. Preparation/command/readout failures and abandonment discard
partial output. `WaveSolver.run` retains automatic-engine pace estimation and restarts
through the existing CPU dispatch from zero state, with a fresh aligner and complete
response; no abandoned GPU prefix is joined to CPU output. Shared readout overhead
contributes to actual elapsed time and must be measured without hiding it.

The bare MetalSimulation protocol has no Core types; the original Metal solver only
adds protocol conformance. Frozen original consumers omit the optional shared backend
files and keep original equations and their older manifests/dependencies. Their source
reference gates stay independent of application default dispatch. CPU integration and
optimized unmasked box behavior remain unchanged.

Focused actual-M4-Max tests pass all six patterns for box/plan/mesh output across
0/1/2/63/64/65/127/128/129/257 steps, counted cancellation/nonterminal callbacks,
forced automatic abandonment with complete fresh CPU restart, short retained GPU
runs, four concurrent independent histories and inactive/nearest-cell source padding.
A full local check passes 186 Swift tests before the separate new padding test; the
padding test and final lint also pass. This is preliminary application binding evidence.

## Verified comparison checkpoint

Producer `a2a932f03c4f8880e29188bedf5bfc859954af4b` passes complete
[mini Metal output](https://github.com/emmettl/RoomCAD/actions/runs/38025643450),
[all-axis thin binding](https://github.com/emmettl/RoomCAD/actions/runs/38025757119)
and [CPU continuity](https://github.com/emmettl/RoomCAD/actions/runs/38025844993)
gates and M4 Max counterparts. All 90 Metal runs/45,144 samples per variant per host
and 18,432 timed samples per original/shared variant match exactly across hosts.
Full generator outputs/non-timing diagnostics and saved WAV/metadata match too.
Sixteen strict production controls include fifteen negative cases, including actual
GPU generator presence and complete timed histories. Ninety minimal-grid runs retain
45,144 samples per each of four backends with exact same-backend bits; nine negative
controls and independent all-axis pressure/velocity/lookahead oracles pass. Prior
CPU/original Metal thin output remains exact. Full 72-run CPU generator/save output
is unchanged from the alpha.9 default checkpoint.

The [full mini app gate](https://github.com/emmettl/RoomCAD/actions/runs/38025289108)
at `ae54cf65f7454521fa321db26011ecf125fc7a6d` passes 187 Swift tests, all five new
focused actual-device tests, lint, eight Python release tests, compilation, packaging,
deep signature verification and a visually inspected actual-Metal snapshot. Application
source/tests/manifests/packaging and check scripts are unchanged at the final benchmark
producer; only separate fixtures/benchmark verification were subsequently added.
Frozen original-manifest CPU and Metal masked reference reports still pass locally.
The final evidence checkpoint changes documentation only.

Max shared/original median wall ratios are 1.206/1.423/1.446 on
3,888/29,610/331,800 cells; mini ratios are 1.207/1.179/1.034. These are balanced
warmed whole-simulation measurements on live hosts. Compilation and per-run
layout/preparation/initialization are retained separately; compilation measurements
include system shader-cache state, and original default pipelines were initialized
first. No cold-compile or isolation claim is made. The measured steady-state overhead
requires its own optimization/measurement task before a default switch.

[Aggregate evidence](wave-production-metal-verification.json) is public; complete
raw reports, timings, dependency/source provenance and lossless logs are preserved
privately in Edgerton. The original Metal default and engine/budget policies remain
active. No app binary release or empirical accuracy claim accompanies this binding.
