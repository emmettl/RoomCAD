# Production Metal comparison and adoption

Current production uses the [verified shared Metal default](SHARED_METAL_DEFAULT.md)
with exact alpha.12. The following checkpoints retain the comparison history.

Initial candidate: 10 October 2026. `WaveSolver.usingSharedMetal(context:)` selects a shared
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

## Published alpha.11 comparison

The application now pins exact released alpha.11, commit
`72dae5da882774ef9739d27c06c4a06a9c8ea66d`, using capacity-bounded larger-grid
field groups. Candidate `170a90636dacd07d4606ba0a039b0649642b080a` passes
[mini Metal](https://github.com/emmettl/RoomCAD/actions/runs/38028549680),
[full application](https://github.com/emmettl/RoomCAD/actions/runs/38028660917),
[thin](https://github.com/emmettl/RoomCAD/actions/runs/38028908747) and
[CPU continuity](https://github.com/emmettl/RoomCAD/actions/runs/38029066655) gates
and Max counterparts. All 90 complete Metal runs/45,144 samples per variant, every
18,432 timed original/shared sample, generator/non-timing diagnostics and saved
WAV/metadata remain exact across hosts and against alpha.10. The 72-run CPU output/
generator/save and all four 90-run thin streams also retain exact prior numerics.
All strict negative controls pass. Full app checks pass 187 Swift tests, lint, eight
Python release tests, build, packaging, deep signature verification and a visually
inspected actual-Metal snapshot. Final checkpoint changes docs only.

Max shared/original median ratios are 1.178/1.208/1.162; mini ratios are
1.294/1.343/1.029 on 3,888/29,610/331,800 cells. Larger Max ratios improve
from the retained alpha.10 1.423/1.446; the mini large grid remains about 1.03.
Smaller live-host measurements remain variable, including worse mini small/medium
ratios; preserve every repetition and avoid selecting only apparent improvements.
No isolated speedup or universal optimality is claimed. The original GPU default
remains active. Mixed source-observation command dispatch cost is the next bounded
question to measure and address before default adoption.

[Aggregate alpha.11 proof](wave-production-alpha11-verification.json) is public; full
raw evidence is retained privately in Edgerton. Frozen reference pins, application
numerical code, engine/cancellation/abandon/budget policy and fixture identities stay
unchanged. No app binary release or empirical accuracy claim is made.

## Published alpha.12 comparison

Exact alpha.12 (`f464e04866903bfc7c9ce94c34d31125a776d270`) combines mixed
receiver sampling in one guarded dispatch. Candidate
`e7513bb27cb1e0d28dd716c92f474fcea8832297` passes full Max/M4 counterparts and
[mini Metal](https://github.com/emmettl/RoomCAD/actions/runs/38030914455),
[application](https://github.com/emmettl/RoomCAD/actions/runs/38031106577),
[thin](https://github.com/emmettl/RoomCAD/actions/runs/38031240672) and
[CPU](https://github.com/emmettl/RoomCAD/actions/runs/38031478380) gates.
Every complete case, 90 Metal runs/45,144 samples per variant, 18,432 timed
original/shared samples, generator/non-timing diagnostics and saved WAV/metadata
remain exact across hosts and alpha.11. The 72-run CPU comparison and all four
90-run thin streams remain exact too. All strict negatives pass. Full app checks
pass 187 Swift tests, lint, eight Python release tests, build, packaging, deep
signature verification and a visually inspected actual-Metal snapshot. The final
evidence checkpoint changes documentation only.

Max shared/original wall ratios are 1.081/1.065/1.122; mini ratios are
1.085/1.056/0.964 on 3,888/29,610/331,800 cells. The former largest Max
alpha.10 ratio was 1.446. Preserve all repetitions: these live-host results establish
bounded practical cost on the tested grids, not universal optimality or isolated
speedup. Model/source/ownership gates and measured cost now support a separate
application-default selection task. Original GPU remains the default for this pin
checkpoint; startup/resource fallback and actual-default generator/save/packaging
checks precede its switch.

[Aggregate alpha.12 proof](wave-production-alpha12-verification.json) is public;
complete data and logs are retained privately in Edgerton. No application numerical
source, frozen reference pin, engine/cancellation/abandon/budget policy or fixture
identity is changed here. No app binary release or empirical accuracy claim.
