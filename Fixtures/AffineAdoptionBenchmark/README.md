# Complete actual affine application trace fixture

This fixture builds temporary AcousticCore and RoomDocument modules from complete
committed application sources. Only the two fitting files receive fixture-only
statement trace hooks and private-probe visibility. Every patch has an exact unique
anchor and reverses byte-for-byte to the original source. The shared public fit
expression is unchanged; legacy arithmetic remains verbatim. Generated source,
all binding patches/hashes, exact Core pins and native outputs are retained.
Trace.swift is absent from production targets. Calls run serially; its mutable
recorder state is confined to the standalone fixture.

The 39-case cohort includes analytic clean energy decays at 8/48 kHz, compensation
on/off, deterministic noise and a late burst, short/silent/threshold responses,
large-offset index probes, delayed seconds fits, unavailable responses, all eight
rendered/measured octave bands, complete explicit CPU and actual Metal generated
wave responses and response summaries, and both existing absorption-calibration
operations (geometrical generation and erratic-band best-step feedback). Source and
receiver UUIDs are fixed. Inputs are numerical/model probes, not invented measured
room data; measured fixture identities and credits remain unchanged.

Capture retains complete native input/filter/energy/curve/window/fit/prediction,
every noise setup/floor/window/crossing/iteration/tail, all response metadata and
summary arrays, and complete calibration inputs/channels/steps/best/fitted-room data.
Each binary vector declares offset/count/32-or-64-bit width/SHA-256. All samples
and precision are preserved as little-endian IEEE754, including original nonfinite
coefficients. No plot-only reduction or sample subset is used.

`Scripts/capture-affine-adoption.sh` requires a clean committed Git producer and
compiles both variants optimized with warnings as errors. Original fitting uses
protected pre-alpha.18 source and exact alpha.17; shared uses exact alpha.18.
`audit-affine-adoption-fits.py` independently derives Fraction OLS over every actual
selected native window and checks shared slope, origin ordinate and every diagnostic
prediction. Original inaccurate/nonfinite coefficients remain findings. These
predictions audit the returned line; actual noise-query operations are separately
recorded by source-bound trace hooks.

The separate full policy/source/corruption gate now passes on both physical Macs.
It checks every selected window/noise/tail/parameter/calibration operation, complete
source/native coverage and 25 categories of coherent corruptions. Both physical
Macs' full captures, app/package checks and affected frozen/current reference
suites pass; complete portable archive replay is retained. See
[accepted scope](../../docs/benchmarks/SHARED_AFFINE_FIT.md).
The initial 38-case automatic-wave preliminary phase remains separately retained;
the 39-case version explicitly requires actual CPU and Metal wave execution.
