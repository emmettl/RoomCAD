# Shared affine fitting adoption candidate

The candidate updates exact ContinuumKit alpha.18 and delegates the two actual
RoomCAD unweighted fitting kernels to Numerics.AffineLeastSquares. RoomParameters
keeps sample/block-index coordinates; DecayAnalysis keeps explicit seconds. Onset,
backward integration, thresholds, windows, noise smoothing, five crossing iterations,
EDT/T20/T30 extrapolation and absorption-feedback policy remain app-owned.

This is an intentional arithmetic improvement after the original fitting audit;
complete independent accuracy evidence is required before acceptance. It is not
claimed to preserve the original inaccurate coefficients byte-for-byte. Checked
fit/query failures map to unavailable optional fits. Noise crossings use the
origin-based returned line. Noise-estimation starts are bounded before integer
conversion, including nearly flat negative slopes whose five-decibel intervals
overflow Double/Int; the last-tenth clamp policy remains the same.

Protected original fitting source controls preserve old frozen consumers without
changing their pins, source identities, cases or bounds. The alpha.17 FFT migration
cohort is now explicitly replayed at its accepted producer rather than weakening
its byte-identical caller/pin assertions. Current fitting/bands/parameters require
the new independent application gate; old FFT evidence is not current adoption.
The existing production-wave consumers resolve alpha.18, whose released CAD,
response, wave, FFT and reference sources are byte-identical to alpha.17.

The [Core adoption plan](https://github.com/emmettl/ContinuumKit/blob/main/docs/extraction/ROOMCAD_AFFINE_ADOPTION_PLAN.md)
requires complete source-bound selected windows, fit/prediction records, every
noise/crossing/tail iteration, measured and wave-rendered band/response summaries,
absorption-feedback histories, independent Fraction/reference/corruption controls,
both physical Macs and actual-Metal application/package/snapshot checks. These
acceptance gates remain pending. Do not merge this candidate before they pass.
Measured fixtures/credits and original numerical assertions remain unchanged;
package/application verification does not establish empirical acoustic accuracy.
