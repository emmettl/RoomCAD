# Acoustic measurement result-domain audit

This source audit is based on verified-calibration candidate
`52a0a331b1f4d9ff5db202063a303f0bc9899b4c`. It changes no production
source, numerical algorithm, fixture, saved representation or dependency pin.
The preceding final-calibration verification remains a separate acceptance task.

The existing `RoomParameters` API does not represent all unavailable quantities
with optional values. Empty or silent energy returns nil decay times, negative
infinite C50/C80, NaN D50 and zero centre time. The public band-measurement path
has the same silent-result behavior. Default JSON encoding fails. These results
must not be treated as a complete finite measurement merely because the method
returned a `RoomParameters` value.

Infinite clarity is also possible with nonzero energy: a 2,400-sample constant
record at 48 kHz has all its energy within both early windows, D50=1 and positive
infinite C50/C80. It has no T30 because its finite backward integral ends only
33.802 dB below the total and never reaches the -35 dB endpoint. This distinguishes
undefined normalization from a meaningful extended-real clarity limit; a future
checked result needs an explicit policy for each, rather than rejecting every
nonfinite output identically or silently coercing them to zero.

At 4,800 and 9,600 samples, a constant-energy input has enough finite-integral
range to produce positive T30 values of 0.14623330351621788 and 0.2939521277320455
seconds. Neither input has a decreasing energy envelope. Noise compensation falls
back to the raw result because no noise crossing is found. This is a finite-record
fit, not evidence of a physical reverberation decay. Separately, truncating an
exact 1.2-second exponential at 0.12 seconds yields T30=0.23998466476990346 seconds;
the three-second record gives 1.1999999999996602 seconds. Independent backward
integration and centred OLS reproduce these numerical interpretations. Direct
sample and energy APIs can differ by rounding because coordinate scaling occurs
at different points; their comparison uses four output ULPs, not byte parity.

Run `swift test --filter MeasurementDomainAuditTests`. Four tests characterize
the current contracts and deliberately preserve the observations above. These
controlled inputs are not measurements of a real room. They do not establish a
general noise, truncation or empirical-error classifier.

The next bounded task should define a checked acoustic measurement result with
explicit input domains, missing-energy outcomes, unavailable decay windows,
extended-real clarity and capture/fit diagnostics. Preserve legacy APIs and
measured fixture identities. A diagnostic must report what was actually checked;
finite fitted T30 alone cannot certify capture adequacy. Complete source/native
evidence, independent references and coherent input/output controls precede any
production adoption or extraction into ContinuumKit. Noise correction, averaging,
onset selection, filtering and fit-window policy remain explicit model choices.
