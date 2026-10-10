# Shared Metal application default

The application product selects exact released Core alpha.12 for GPU evolution,
source injection and native observations after complete model/source/ownership and
actual-application output/timing gates. The backend uses one immutable compiled
device context across independent calls; each run owns its queue, fields, plans,
sparse staging, channels and lookahead. Numerical library code, hardware-independent
model contracts and caller engine/crossover/budget policies stay unchanged.

Default selection is lazy: CPU-only runs do not ask for a Metal device or compile
GPU pipelines. The existing app-owned default-device choice creates the optional
context when the GPU route is first requested. Missing hardware/context preparation
keeps the existing original-resource/CPU fallback behavior. Run failure/cancellation/
nonterminal abandonment retains the original nil check and complete fresh CPU
restart, with no joined GPU prefix or shared mutable run state.

`usingOriginalMetal()` explicitly selects the retained original control. The
application manifest's existing `ROOMCAD_SHARED_WAVE_DEFAULT` setting enables this
selection; frozen original numerical consumers omit the setting and optional backend
files, keep their bare protocol, equations and original dependencies. No UI setting
or measured-fixture revision accompanies this default switch.

Six focused actual-device tests pass complete original/shared outputs across all
patterns/representations/boundaries, callback cadence, actual abandoned GPU/fresh CPU
restart, concurrent histories, source padding and lazy shared-default/original control.
The full local check passes 188 Swift tests, lint, eight release-script checks and
build. The verified checkpoint below retains the complete three-way output, generator/save,
all-axis thin evidence, original-manifest compatibility and mini application gates.

The preceding alpha.12 whole-simulation ratios are Max 1.081/1.065/1.122 and mini
1.085/1.056/0.964 on 3,888/29,610/331,800 cells. Every repetition remains retained;
this bounded live-host cost follows the earlier demonstrated regression and does not
claim isolation/universal optimality. Numerical/ownership verification and practical
cost supported the separate actual-default gate recorded below. Original numeric
retirement remains a separate provenance-preserving task. No app binary release or
empirical acoustic accuracy is claimed by this adoption.

## Verified default checkpoint

Clean producer `7b0a487c1504fdf36df40c34f037ce86c865b34f` passes [full mini application](https://github.com/emmettl/RoomCAD/actions/runs/38031811398),
[actual Metal production](https://github.com/emmettl/RoomCAD/actions/runs/38032516663) and [all-axis thin](https://github.com/emmettl/RoomCAD/actions/runs/38032721754)
gates and local counterparts. All 90 three-way runs/45,144 samples per variant,
18,432 timed original/shared samples, complete generator/non-timing diagnostics and
saved WAV/metadata agree across M4 Max/M4 and the prior alpha.12 pin checkpoint.
Four-backend thin streams retain exact complete histories and independent two-step
clocks. Fifteen Metal and nine thin negative controls pass. Frozen original-manifest
CPU/actual-Metal masked checks retain twelve complete histories per backend, inputs,
reference and error contracts with their original dependency pin.

Both full checks pass 188 Swift tests, lint, eight release-script tests and build.
Mini packaging, deep signature verification and the actual-Metal snapshot pass;
the retained image was visually inspected. Six focused tests cover actual default
selection/context reuse, complete signals, cancellation, concurrency, source padding
and abandoned GPU/fresh CPU restart. The final checkpoint changes documentation only.

Current shared/original median ratios are Max 1.115/1.131/1.103 and mini 1.089/1.100/1.042.
All balanced repetitions and initialization/preparation measurements remain retained
with their live-host limits. This is an accepted bounded practical cost, not a
universal performance or empirical acoustic accuracy claim. The lazy shared GPU
backend is now the application default; the explicit original control and existing
resource/CPU fallback remain.

[Aggregate proof](shared-metal-default-verification.json) is public; full raw reports,
source/dependency envelopes, logs, image and portable crossed/prior comparator are
retained privately in Edgerton. Retirement follows separately: preserve immutable
original-source reconstruction and numerical oracles, audit resource/availability
checks that feed engine budgets, then remove duplicated production loops with full
application/fallback checks. The optimized unmasked box CPU contract remains distinct.

The [original GPU implementation is now retired](RETIRED_ORIGINAL_METAL.md), with protected verification-only
reconstruction and selected-backend availability/planning. Missing shared context now
selects CPU directly; the old inline-GPU preparation fallback is retired. Both-host
output, full application and packaged exclusion gates pass; no new Core tag is needed.
