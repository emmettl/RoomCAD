# Verified calibration outcomes

`AbsorptionCalibration.fitValidated` preserves the legacy search and makes one
additional simulation of the assembled selected room. Per-band historic best
times remain available as `selectedBest`; `verification` contains measurements
from the actual returned room. Verification never alters selected factors or
fills missing measurements from history. The controlled coupled counterexample
is recorded in [the source audit](CALIBRATION_OUTCOME_AUDIT.md).

The input contract requires eight optional finite positive targets, finite
nonnegative relative tolerance and a nonnegative maximum search-update count.
Malformed inputs fail before simulation. No targets returns the unchanged room
without simulation and does not count as convergence. Each targeted band is
unavailable, measured within tolerance or measured outside tolerance. All targets
match only if at least one was supplied and every one is measured and matched.
An unavailable receiver prevents a band from supplying the legacy all-receiver
mean. Relative-error arithmetic may overflow for an extremely small positive
target; this remains an outside-tolerance result and is safely formatted.

The search retains its legacy scaling, saturation, secant/fallback, independent
band selection and early stopping policies. In particular, an unavailable
search measurement does not cause additional search iterations. Changing that
policy or improving optimization is a separate bounded task. `iterations` counts
allowed updates; `steps.count` counts search simulations and `simulationCount`
includes final verification. Callback and cancellation errors propagate.

RoomCAD applies the selected room and reports final preview T30 coverage. Its
progress counts completed simulations without mistaking the extra verification
for a search update. The measured-room benchmark retains historical selection
in its report and separately prints final assembled-room T30, measured coverage
and matching coverage. Its existing scene scaling still uses selected factors.

Focused checks cover coupled selection, actual final-response measurement,
unavailable receivers, exact matching, unmet saturated search, legacy selection
parity, invalid inputs, no targets, search errors, verification errors and safe
reporting. Per-band assessment separately tests missing/nonfinite/nonpositive
measurements and the inclusive tolerance boundary. The frozen original numerical
guards and alpha18 pin remain enforced; reviewed identities bound only the new
API and its two callers. Source controls reject ten coherent policy/caller
mutations and three missing-file controls.

These are numerical and source-contract checks under the supplied simulator.
They do not establish empirical room accuracy or general calibration convergence.
Heavy BRAS validation remains a separate `make validate` run. Application checks
include `make check` and physical Mac mini `Scripts/ci-check.sh` with actual Metal,
release packaging, strict signature and an inspected headless snapshot.
