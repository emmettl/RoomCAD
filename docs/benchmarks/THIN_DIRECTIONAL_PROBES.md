# Directional sampling on two-cell dimensions

The original cell rule `min(max(Int(position/spacing),1),n−2)` returns zero when
n=2. The face-pair sampler then reads a negative or wrapped minus-face address;
Core observation preparation correctly rejects that address. This is a sampling
safety/model-policy gap, not a numerical update or source-scaling problem.

`WaveSolver.velocityProbeCell` retains the existing rule for n≥3 and uses cell 1
on a two-cell axis. Its negative face is the actual internal stored face; its positive
face is the existing closed/unused boundary velocity slot. Their average is the
existing cell-centred reconstruction extended to the upper cell, with no synthetic
zero or clamping in Core. This remains quantized app-owned sampling, not a claim of
spatially converged interpolation on a minimal grid.

Optimized unmasked CPU, masked CPU, original Metal layout and shared preparation
use the same rule. Pressure stencils, source weights/scaling, pulse, update kernels,
axis precision, lookahead and terminal policy remain unchanged. Invalid velocities
are not fabricated. CPU and Metal retain their declared different pressure/axis
rounding. This correction establishes a defined result for formerly invalid addresses;
no before/after physical-accuracy claim is made for them.

Four focused tests cover every axis/minus-face address, unchanged ordinary selections,
a prescribed uniform native-face field with a closed boundary (half the internal
normal velocity), and whole two-step box/plan/mesh output. Both the original sampling
kernel and packaged Core Metal sampling execute on the actual device. The two-step
oracle derives first injection, next internal velocity/pressure and microphone output
from independent recurrences. The first pressure can be zero while its microphone
output uses the later half-step velocity; the final sample uses the explicitly retained
half-step fallback. Original/shared CPU values remain bit-identical.

`Scripts/check-thin-probes.sh OUTPUT` fetches the committed application and exact
released alpha.9 dependency. Nine x/y/z × box/plan/mesh scenes retain all layout/source/
receiver inputs and complete CPU/shared/actual-Metal values/bits at 0/1/2/63/64/65/127/
128/129/257 steps: 90 runs and 45,144 samples per backend/host. The independent guard
recomputes source rounding and the two-step time oracle, checks same-row negative
addresses, full histories, pattern coverage and exact dependency. Seven adversarial
controls reject changed/missing scope, cells, samples and dependency. CPU/GPU values
are not forced into one precision contract. Corresponding crossed scene reports must
be identical; full application lint/tests/packaging/signing/actual-Metal snapshot stay
required. Existing measured response fixtures are unchanged.

This is the geometry-owned gate needed before default masked CPU adoption. Default
migration and retirement of retained original loop/reference code are separate changes;
Metal production integration still has its own ownership, pipeline and abandonment gates.
