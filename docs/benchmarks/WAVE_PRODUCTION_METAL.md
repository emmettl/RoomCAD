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

Before merge/default adoption, retain complete fetched optimized original/shared
Metal reports with layout/source/receiver/clock/value/bit identities, all minimal
directional axes, full wave-enabled generator/save parity, frozen-original compatibility,
representative compilation/setup/repeated-run timing on both physical Macs and the
mini full app packaging/signature/actual-Metal snapshot. Existing independent references
remain strict. No numerical accuracy, throughput acceptance or GPU default switch is
claimed by this candidate.
