# Retired production GPU implementation and selected availability

Application targets now use only released shared masked CPU/Metal evolution, injection
and sampling. The original GPU class and kernel source move verbatim into one protected
verification source reused by tests and Metal/thin benchmark source links. A complete
compressed original Git snapshot and manifest preserve reconstruction. The common
app-owned grid layout moves byte for byte into WaveGridLayout.swift; it is independently
checked against that original blob. Geometry/material/opening/microphone policies stay
with the application, and optimized box CPU arithmetic remains a distinct contract.

Availability now asks the same selected GPU implementation used by execution. CPU-only
routes avoid GPU lookup. An unavailable shared context uses CPU directly and the CPU
planning budget/crossover. The former inline-GPU startup/preparation fallback is
intentionally retired; it is not silently presented as unchanged behavior. Normal
available-context budgets remain unchanged. Execution failure and nonterminal GPU
abandonment still discard partial histories and restart from zero on CPU; cancellation
still returns nil. The original 128-step policy is now app-owned. Four new tests verify
unavailable/forced routes, actual planning, failure/cancellation and CPU-only dispatch;
six existing actual-device tests retain complete signals, callback cadence, concurrency,
source padding and actual abandoned GPU/fresh CPU restart.

Fourteen corruption controls protect original CPU/Metal snapshots, Git identities,
verbatim numerical implementations, canonical links and the exact moved layout. Frozen
source-free/geometry consumers reconstruct both controls inside their copied module,
omitting only the self imports, and retain full original fallback and old dependencies.
Five original CPU wrappers and two complete Metal/Grid bindings remain byte-identical
to the pinned preparers. Twelve CPU and twelve actual Metal masked histories retain
exact fields/input/reference/error contracts, and all 36 extrusion layouts pass their
assignment and zero-fallback gates.

Clean producer f97d6721d3b9018234891d6eb732d47d477049d7 passes all full gates. Both
hosts pass 192 Swift tests, lint, eight release-script tests, fourteen source guards
and build. Actual packaged symbol inspection on the mini proves shared backends present
and original CPU/Metal implementations absent. Packaging, deep signature verification
and the actual-Metal snapshot pass; the retained image was visually inspected.
[Application](https://github.com/emmettl/RoomCAD/actions/runs/38037164804),
[Metal](https://github.com/emmettl/RoomCAD/actions/runs/38037297002),
[thin](https://github.com/emmettl/RoomCAD/actions/runs/38037519871) and
[CPU](https://github.com/emmettl/RoomCAD/actions/runs/38037638231) pass at that exact head.

All 90 three-way Metal runs/45,144 samples per variant, 18,432 timed original/shared
samples, complete generator/non-time diagnostics and saved WAV/metadata remain exact
across both Macs and the preceding shared-default checkpoint. The complete 72-run CPU
cases/36,696 samples per variant and full generator/save data remain exact against the
preceding CPU retirement. Four-backend all-axis thin streams/45,144 samples per backend
retain prior complete histories and independent clocks. Fifteen Metal, ten CPU and nine
thin negative controls pass. The final checkpoint changes documentation only.

All balanced live-host timing repetitions and preparation measurements remain retained
without isolation/universal-performance claims; compilation of the original reference
now belongs to verification targets. [Aggregate proof](retired-original-metal-verification.json)
is public; full raw fields, histories, source/pin envelopes, logs, inspected image and
portable prior/crossed comparator remain private in Edgerton. No Core API/tag/equation,
measured fixture, saved identity or application binary release change accompanies this
retirement. Numerical/source conformance does not establish empirical acoustic accuracy.
