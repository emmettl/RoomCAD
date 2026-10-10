# Production wave-loop integration

Checkpoint: 10 October 2026. The application dependency is prepared at exact
ContinuumKit `0.1.0-alpha.10`, commit `da7cb5f5ac642edc57e8433c6150dceca6b9edd9`.
The [source-free benchmark binding](SHARED_WAVES.md) and Core's independently
verified forcing/observation APIs provide the starting point. Updating this pin
does not replace a production loop. Measured room fixtures remain application-owned.

## Bounded migration order

1. Bind the existing masked CPU loop beside a shared implementation, initially for
   explicit comparison. Preserve `WaveSolver.simulate`'s optimized unmasked box path.
   Compare complete microphone outputs for real box/plan/mesh layouts and opening,
   rigid, heterogeneous-loss, thin and tilted cases. Only switch the masked default
   after numerical, cancellation, full-response and timing gates pass.
2. Bind the existing Metal loop beside a shared implementation, using an explicitly
   supplied physical device. Compare complete original/shared GPU outputs independently
   of CPU/GPU tolerance checks. Preserve the automatic engine's abandon/restart policy.
   Switch its default only after actual-device, lifetime and timing gates pass.
3. Retire duplicated production update/injection/sampling code after both defaults
   pass full application checks. Keep immutable original-source reconstruction and
   benchmark provenance available for regression; do not weaken frozen oracles.

Each step is a separate reviewable change. Application adapters own layout and run
policy; Core owns checked field evolution, sparse injection and native sampling.

## Adapter contract

| Existing responsibility | Integration requirement |
| --- | --- |
| `WaveSolver.gridLayout` | Retain cell-centre occupancy, six face arrays in their existing order, normals/material/opening selection and staircase area weighting. Supply the resulting data to `PreparedWaveGrid` without rebuilding geometry in Core. |
| Source preparation | Retain ordered source cells and Float weights already scaled by `c² dt / V`. Use `PreparedPressureSource` without scaling twice; evaluate the existing midpoint pulse and convert it to Float in the existing order. |
| CPU receiver preparation | Preserve eight ordered cell/Float-weight slots and the current clamped velocity-cell rule. Pass the original Double microphone axis; pressure-only microphones omit velocity. |
| GPU receiver preparation | Preserve the existing Float-axis conversion and Float sampling. Use opaque device observation/source plans prepared for the same grid and physical device. |
| Time alignment | Accept post-source frames starting at pressure index 1. Keep one-frame lookahead across batches and use the explicitly labelled final-half-step fallback exactly once after successful completion. |
| Microphone output | Keep `a * pressure - (1 - a) * c * velocity`, its Double operation order and application-owned pattern share. Native fields are normalized pressure/velocity; do not introduce an extra density factor. |
| Longer history | Append aligned frames to application-owned channel arrays. Keep Core's retained histories bounded and avoid full-field snapshots per production step. |
| Cancellation | Check masked CPU cancellation before every 64-step batch and GPU cancellation before every 128-step batch, including the initial batch. Discard incomplete application output and return nil. |
| GPU abandonment | After synchronous completed batches, retain the delay seam and existing nonterminal abandon callback. Restart from fresh zero state through the current CPU dispatch, with a fresh aligner; never join abandoned GPU samples to CPU samples. |
| Failure and ownership | Catch preparation/readout/command failures at the app boundary and retain nil/fallback behavior. Each simulation owns its stepper, output and alignment state; concurrent calls must not share mutable state. |

Core clocks represent acknowledged complete steps. Sparse readout finiteness is not
full-field certification, and a readout error can follow a completed step. Application
failure discards the response; it must not claim field rollback or empirical accuracy.

## Acceptance evidence

Retain complete original/shared per-channel outputs and their clocks, layout/source/
receiver identities, exact resolved dependency and clean producer metadata. Exercise
0, 1, 63/64/65, 127/128/129 and 257 steps, mixed omni/directional patterns, repeated
receivers and arbitrary batch boundaries. Same-backend source parity should remain
exact where the declared arithmetic matches; existing CPU/GPU tolerance gates remain
separate. Also compare full `responses`/generator outputs, octave grouping, audio-rate
conversion and saved response/document identity.

Use counted cancellation closures at the initial and subsequent batch boundaries.
Exercise independent concurrent runs, forced GPU abandonment, short non-abandoned
runs and fresh CPU restart. Existing `busyGPU` and `abandonRule` tests remain active.
Run `make check` and the mini's complete application job, including packaging, signing
verification and a headless actual-Metal snapshot. Measured BRAS validation remains
a separate gate when a change alters acoustic assumptions or recorded responses.

Record representative grid preparation and repeated-run timing on both Macs before
switching defaults. The existing masked CPU loop uses parallel slabs, while the
released Core CPU stepper supports caller-selected serial/slab execution; numerical
equivalence alone does not establish
acceptable production throughput. The existing GPU solver reuses compiled pipelines,
while Core currently prepares pipelines per stepper. Measure initialization and
steady-state costs separately and address a demonstrated regression before default
adoption. These are explicit readiness questions, not permission to change results,
relax verification, or silently substitute backends.

## Current implementation checkpoint

The [masked CPU application binding](WAVE_PRODUCTION_CPU.md) now passes complete
original/explicit-shared/actual-default outputs, cancellation/concurrency, full
wave-enabled generator/save and mini application gates. Exact alpha.9 execution
retains the original serial/slab policy. The independently verified all-axis
[two-cell directional rule](THIN_DIRECTIONAL_PROBES.md) closes the remaining address
gate. The [application default checkpoint](SHARED_MASKED_CPU_DEFAULT.md) records full
cross-host numerical continuity, raw timings and retained original-reference checks.
The optimized unmasked box path remains a separate contract.

The [optional Metal application binding](WAVE_PRODUCTION_METAL.md) now passes
complete original/shared/default output, generator/save, all-axis thin, cancellation,
concurrent ownership, nonterminal abandon/fresh CPU restart and mini application gates.
Compiled Core pipelines can be reused through the released immutable device context.
Representative live-host measurements retain modest to substantial steady-state
overhead: Max ratios 1.21/1.42/1.45; mini 1.21/1.18/1.03 on three grids. The next
bounded task identifies and reduces that cost without relaxing synchronization,
source/receiver arithmetic, output ownership or policy. Production Metal retains the
original default until its timing acceptance gate passes; numerical conformance does
not establish empirical acoustic accuracy.
