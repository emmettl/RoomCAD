# Current application masked CPU binding

Checkpoint: 10 October 2026. The application now selects the shared masked CPU
backend by default, using exact released ContinuumKit alpha.9. Explicit original and
shared controls remain available for conformance; the optimized unmasked box path
retains its existing contract. See the [default adoption evidence](SHARED_MASKED_CPU_DEFAULT.md).
The alpha.8 and alpha.9 comparison history remains recorded below.

The adapter consumes the actual `gridLayout`, six wall blocks, pulse and receiver
rules. It retains unique active zero source writes and all nonzero writes in their
original order. Only inactive zero slots and repeated zero nearest-cell fallback
padding are removed to satisfy Core's unique active source mapping. Nonzero padding,
malformed arrays and invalid addresses reject before field allocation/access.
Receiver pressure slots remain ordered and repeated; CPU axes remain Double.

Each call owns its prepared plans, CPU fields, channel arrays and one-frame lookahead.
It checks cancellation before each original 64-step boundary, samples after forcing,
asserts output clocks/counts, keeps lookahead across batches and explicitly finishes
with the original final-half-step velocity. Pattern mixing and sound-speed scaling
remain in the app, with no extra density factor or full-field copy per production step.
Failures discard partial output and return nil. Empty calls preserve the original
no-cancellation behavior; pressure-only thin grids omit unused velocity reads.
The app-owned two-cell directional rule is now independently verified on all axes;
malformed addresses still reject safely before field access.

An internal generator configuration seam drives the same complete public generator
body with an explicitly selected CPU backend. The public route uses identity
configuration. Wave comparisons enable `lowFrequencyModel` explicitly and require
actual CPU wave runs; a geometrical-only generator result is not wave evidence.

Nine focused tests exercise real plan/mesh outputs at 0/1/63/64/65/127/128/129/257
steps, padding, input rejection, exact counted cancellation, unchanged box dispatch,
full response spectra/octave/diffuse correction, full wave-enabled generation and
save/reopen, concurrent independent calls and thin pressure-only/empty output.
Existing independent acoustic references and measured fixtures are unchanged.

Run `bash Scripts/check-wave-production-cpu.sh OUTPUT` from a clean committed
candidate. It fetches the committed app through Git and builds its actual library in
an optimized testable consumer, retaining the exact resolved Core dependency.
Eight independently chosen rigid/lossy/open/masked/tilted/plan/mesh/thin/padded layouts
have 72 complete original/shared output runs and 36,696 mixed samples per implementation.
All layout/source/receiver inputs, native input clocks, values and bit representations
are retained. The full generator includes both complete channels, non-timing
diagnostics, settings and actual saved WAV/metadata. A separate postcondition rejects
missing scope, clock/dependency discrepancies, shape/bit differences and changed
saved output. Nine adversarial controls cover altered and incomplete reports.

Three representative grids retain preparation/initialization timing and balanced
original/shared repeated 1,024-step runs, after warmup. Timings are measurements,
not numerical conformance or a fixed acceptance threshold. Record both Macs before
default adoption. Initial local exploration found a substantial large-grid serial
CPU regression; final committed-candidate evidence must determine the next optimization.
Do not change the automatic engine, crossover/cost budget or cancellation cadence to
hide a throughput regression.

The older source-free fixtures pin Core/reference versions before these APIs. Their
preparers copy every original application Swift file verbatim except this separately
verified optional backend file. The backend protocol and default dispatch require no
Core types; original fixture runs retain original evolution/layout code. This keeps
frozen numerical references and original source-free gates available without changing
pins or validators. Full application checks and the physical mini's actual-Metal
packaged snapshot remain required for this app change.

## Verified executable binding checkpoint

Final producer `ccea958aa3551d79d025de6fff00f2b4d6735db7` passes the
[mini production gate](https://github.com/emmettl/RoomCAD/actions/runs/38016230327)
and complete M4 Max counterpart: 72 complete runs and 36,696 mixed samples per
implementation/device, with zero runtime bit mismatches. Every case/input/value/bit
history is identical across hosts. Full wave-enabled generator channels, fixed input
identities, non-timing diagnostics and saved WAV bytes are also identical.
The producer and independent postcondition pass, including nine adversarial controls.

The [full mini application gate](https://github.com/emmettl/RoomCAD/actions/runs/38016087224)
passes 176 Swift tests, all nine new binding tests, lint, eight release-script checks,
build, release packaging, deep signature verification and the actual-Metal snapshot.
Its candidate is `93612a8a3756715c5f5da3919bc837524145dcb7`; the subsequent
change pins only newly introduced benchmark scene identities. Production/test code,
manifest, CI and verification scripts match through the final numerical candidate.
The final documentation checkpoint makes no executable change.

The mini's shared/original median wall-time ratios are 1.046, 1.936 and 4.132 on
3,888/29,610/331,800 cells. An earlier committed Max run with the same production
code recorded 1.089/1.269/3.922; the final Max repeat recorded 0.910/0.709/1.133
while other CPU work was active. The repeat slowed the original parallel loop too;
retain all measurements rather than selecting an apparent improvement. These are
live-host wall timings, not isolation or performance acceptance. Large-grid CPU
throughput is therefore the next required optimization/measurement gate before a
default switch. No automatic engine or budget policy was changed.

[Aggregate identities and findings](wave-production-cpu-verification.json) are public;
complete raw final and earlier outputs, consumer manifests, fixed input identities,
logs, environment metadata, source identities and the packaged snapshot are retained
privately in Edgerton. The existing acoustic/response fixtures remain unchanged.

## Exact alpha.9 execution checkpoint

Producer `f71403ff34b787f58346dde6cd8ec459cdd107e8` pins released alpha.9 and
uses the original app policy: serial below 4,096 cells, min(z,16) synchronous slabs
otherwise. [Mini production comparison](https://github.com/emmettl/RoomCAD/actions/runs/38019908289)
and M4 Max counterpart pass all 72 runs/36,696 samples per implementation/host.
Complete case inputs/outputs and the wave-enabled generator's channels, non-timing
diagnostics and saved WAV bytes match both Macs and the earlier alpha.8 checkpoint.
The strict postcondition and nine negative controls remain unchanged apart from the
required actual version/commit.

[Mini full application check](https://github.com/emmettl/RoomCAD/actions/runs/38019909989)
passes 177 Swift tests, ten binding tests (including real large-grid parallel work),
lint, eight release-script checks, build, release packaging, signature verification
and actual-Metal snapshot. The later evidence checkpoint changes documentation only.

Shared/original median wall ratios at 3,888/29,610/331,800 cells are
0.958/1.020/1.094 on Max and 1.067/1.216/1.087 on mini. The mini largest-grid ratio
falls from 4.132 at alpha.8 to 1.087 while complete output stays unchanged. Retain
all repetitions; live-host timing is not isolation. The remaining measured cost
includes Core's complete-field certification absent from the original app loop.
[Aggregate evidence](wave-production-alpha9-verification.json) records identities;
raw crossed/generator/manifest/environment/log/snapshot evidence remains private.

The next bounded application gate is directional sampling on two-cell dimensions:
Core currently rejects the original clamp's invalid minus-face address. Review that
geometry-owned probe rule, verify every relevant original/shared CPU/Metal path,
then repeat complete app gates before changing the masked CPU default. The optimized
unmasked box and Metal production migration remain separate contracts.
