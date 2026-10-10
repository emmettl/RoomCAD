# Shared Metal application default candidate

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
build. Before merge retain exact clean three-way original/explicit-shared/actual-default
output, generator/save and all-axis thin evidence on both Macs, original-manifest
compatibility and full mini packaging/signature/actual-Metal snapshot.

The preceding alpha.12 whole-simulation ratios are Max 1.081/1.065/1.122 and mini
1.085/1.056/0.964 on 3,888/29,610/331,800 cells. Every repetition remains retained;
this bounded live-host cost follows the earlier demonstrated regression and does not
claim isolation/universal optimality. Numerical/ownership verification and practical
cost support default adoption subject to this actual-default gate. Original numeric
retirement remains a separate provenance-preserving task. No app binary release or
empirical acoustic accuracy is claimed by this candidate.
