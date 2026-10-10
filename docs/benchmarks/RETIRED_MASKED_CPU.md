# Retired production masked CPU loop

Application products now compile only the shared masked CPU implementation at exact
Core alpha.12. The 124-line duplicate method is moved verbatim into one canonical
verification source; tests and CPU/thin benchmark source links reuse that same file.
Production masked backend selection is mandatory. Optimized box CPU arithmetic and
original GPU resource/availability/fallback behavior remain separate contracts.

A full compressed snapshot of the original Git blob and a hash/provenance manifest
allow immutable reconstruction. Seven corruption controls reject changed numerics
even after the local source hash is refreshed, payload corruption, wrong revision/blob,
misdirected/copied reference links and missing required Git provenance. Mini application
CI verifies the actual original Git object. Frozen source-free and geometry consumers
reconstruct the original method in their copied module, removing only its self import;
their full original masked fallback, dependency pins and numerical oracles persist.
Five complete original generated wrappers are byte-identical to pinned preparers.

Both full application checks pass 188 Swift tests, lint, eight release-script tests,
seven provenance controls and build. Actual packaged symbol inspection proves both
shared backends are present and the original masked implementation is absent. Mini
packaging/signature/snapshot gates pass, and the retained image was visually inspected.
[Application](https://github.com/emmettl/RoomCAD/actions/runs/38034965526),
[CPU production](https://github.com/emmettl/RoomCAD/actions/runs/38034779982) and
[thin probes](https://github.com/emmettl/RoomCAD/actions/runs/38035060932) pass.

Complete 72-run three-way CPU cases/36,696 samples per variant, full generator outputs,
non-timing diagnostics and saved WAV/metadata remain exact across M4 Max/M4 and the
previous alpha.12 checkpoint. Ninety four-backend thin runs/45,144 samples per backend
retain exact prior streams and independent timing oracles. Ten CPU and nine thin
negative controls pass. Frozen CPU/actual Metal masked fixtures retain twelve full
histories per backend and exact input/reference/error contracts. The separate frozen
extrusion fixture compiles and passes all 36 layouts, assignment and zero-fallback gates.

Numerical producer is `6ffaa355eb738ca35aa2b333edf0545f28632447`; application/thin
producer is `0bba31f3f072b9ec3a6e47610778dffde9c0aad5`. Their only difference resolves
symbol inspection through Xcode's xcrun: numerical source, tests, fixtures, manifests
and benchmark producers are unchanged. The initial mini attempt passed tests/build
but failed the bare tool lookup; it and interrupted disk-exhaustion attempts remain
retained. The successful rerun includes the unchanged strict symbol gate.

Live-host shared/original CPU median ratios are Max 0.993/1.052/1.117 and mini
1.107/1.079/1.168. All repetitions remain retained; the reference now compiles in its
verification target, so this is neither an isolated speedup nor a new physical claim.
[Aggregate proof](retired-masked-cpu-verification.json) is public; full reports, logs,
image, source/pin envelopes and portable prior/crossed comparator are retained privately
in Edgerton. The final checkpoint changes documentation only.

Original GPU retirement follows separately, including availability/resource checks
that feed automatic-engine budgets and preserved fallback/abandon/fresh CPU behavior.
No Core API/tag, measured fixture, saved identity or application binary release change
accompanies this retirement. Numerical/source equivalence is not empirical accuracy.
