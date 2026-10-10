# Shared affine fitting adoption

The adoption updates exact ContinuumKit alpha.18 and delegates the two actual
RoomCAD unweighted fitting kernels to Numerics.AffineLeastSquares. RoomParameters
keeps sample/block-index coordinates; DecayAnalysis keeps explicit seconds. Onset,
backward integration, thresholds, windows, noise smoothing, five crossing iterations,
EDT/T20/T30 extrapolation and absorption-feedback policy remain app-owned.

This is an intentional arithmetic improvement after the original fitting audit;
complete independent accuracy and source-bound application evidence now pass. It is not
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
acceptance gates now pass, including complete portable archival replay.
Measured fixtures/credits and original numerical assertions remain unchanged;
package/application verification does not establish empirical acoustic accuracy.

## Accepted evidence

Both physical Macs pass 194 tests, actual Metal, packaging/strict signatures and
inspected headless snapshots. The [mini integration run](https://github.com/emmettl/RoomCAD/actions/runs/38076350589)
passes all fifteen application/current-wave/frozen reference jobs. Later fixture
and checker commits preserve those Package/Sources/Tests bytes exactly.

Complete 39-case captures retain 800 actual-source events, 260 fit records and
2,855,099 full predictions per shared variant, plus every selected window and all
60 noise iterations per variant. The complete 210,357,816-byte native payload and
JSON for each original/shared variant are byte-identical across Macs. Every shared
fit agrees with exact-native Fraction OLS; maximum measured relative slope error
is 3.400708234256367e-16. Original 45 finite inaccuracies and one nonfinite fit
remain findings, not agreements imposed on the improved operator.

Full native representation/source/pin/trace restoration, independent selection,
origin-based crossings/clamps, noise floors/tails/integration/parameters, complete
octave/response-summary references and calibration feedback/best-step checks pass.
Twenty-five categories of coherent scalar/native/completeness/policy/source/pin
corruptions reject. The [mini policy run](https://github.com/emmettl/RoomCAD/actions/runs/38079952222)
uses an independent scalar complex FFT fallback without NumPy; local references
use optional NumPy. Tiny direct DFT controls check normalization/sign. Portable
replay reconstructs every native field and all affected frozen/current suites.
[Exact scope](shared-affine-fit-verification.json) records producer and job identities.

Initial mini policy setup run 38079701569 failed because gh was absent from its
service PATH. The corrected workflow uses a pinned official download action and
the same immutable captured inputs; no numerical bound changed. Short/silent
clarity's native forward-fold singular categories remain explicit, distinct from
an ideal real sum. These are chosen numerical-policy conformance checks, not an
arbitrary-input relative guarantee or empirical measured-room accuracy claim.
