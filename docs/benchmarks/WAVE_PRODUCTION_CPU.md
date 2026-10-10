# Current application masked CPU binding

Candidate: 10 October 2026. `WaveSolver.usingSharedMaskedCPU()` selects an internal
comparison backend for the actual plan/mesh simulation path. It uses the exact
released ContinuumKit alpha.8 dependency. The original production default and
optimized unmasked box CPU path remain in use until throughput acceptance passes.
This is the first executable binding in the [production outline](WAVE_PRODUCTION_INTEGRATION.md).

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
Invalid directional minus-face addresses reject safely; they are not silently moved.

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
