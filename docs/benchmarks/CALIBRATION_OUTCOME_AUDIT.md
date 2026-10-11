# Calibration stopping and assembled-room source audit

Checkpoint: 11 October 2026, source baseline00fc298 after coverage reporting.
This audit changes no calibration algorithm, numerical source, measured fixture,
Core pin or application behavior. The two tests exercise the existing public
calibration callback and retain deterministic receiver identities and seed73.

A zero response with one target produces one simulation, one step, no measured
T30 and unchanged factors/materials. That is an unavailable result, not evidence
that the target was matched. The stopping predicate skips unavailable targets;
the report now qualifies coverage, but structured calibration outcomes remain a
separate API/design task.

The second case deliberately couples its synthetic 500 Hz response to the 1 kHz
absorption factor. It is a controlled callback counterexample, not a model of a
measured room. Actual octave filtering and decay extraction still run. Three
trial factor vectors are retained; the returned per-band selected vector was
never simulated. Its historical 500 Hz time is1.1410431161287495 seconds, whereas
measuring the actual assembled room gives0.8105176396450786 seconds. The 1 kHz
values agree in this selected case. This shows that historical per-band minima
cannot establish the returned room's measured response under general coupling.

The next bounded policy task should preserve the legacy `fit` contract and add
an explicitly verified outcome path: independently measure the assembled room,
retain historical selection and final verification separately, and classify
measured/matched/unavailable targeted bands. Callers must report final measured
coverage rather than relabel historical values. Validate target/tolerance/iteration
domains before invoking callbacks. No source/fixture assertion should be weakened;
the exact historical guards need a separately bounded new-path scope. Adoption
requires full original/final step/response/factor/selection/measurement receipts,
coherent controls, both physical-host package/Metal/signature/snapshot checks and
separate measured-room/empirical assessment where that claim is intended.

Run `swift test --filter CalibrationOutcomeAuditTests` for this source audit.
It characterizes the legacy contract and must remain distinct from verification
of a future opt-in outcome API. AcousticCore remains application-owned.
