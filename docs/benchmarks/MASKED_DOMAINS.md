# Masked source conformance

`bash Scripts/check-masked.sh [output]` runs both actual CPU and Metal masked updates
against ContinuumKit's immutable candidate revision in `Fixtures/MaskedBenchmark`.
The interior-box and split-chamber cases have independent analytic references and
integer masks. The adapter builds closed rigid RoomMesh boxes and calls the actual
`WaveSolver.gridLayout`, requiring occupancy and active-cell face coefficients to agree.
It retains all raw pressure and stored positive-face velocities, including blocked and
inactive values. The global lower exterior face is the solver's implicit zero boundary.

The temporary build copies all AcousticCore source verbatim and uses `@testable` access
with `-enable-testing` to reach actual layout and Metal kernels. It binds the exact
`simulateMasked` coefficient/update blocks, excluding injection, probes and decimation.
That temporary module uses the candidate ImpulseResponseKit; the application's tagged
package dependency and production files remain unchanged. Every copied model source,
adapter and extraction script is hashed in benchmark metadata. This verifies numerical
updates and geometry, not complete impulse-response generation or physical calibration.

Both backends require second-order spatial and temporal convergence separately for all
four fields, energy balance, zero blocked-face velocity, unchanged 100 Pa inactive
sentinels and no leakage into the unexcited chamber. CI `masked` also runs with `all`.
Complete fields and geometry are retained as CI artifacts, with durable evidence in
private Edgerton. Curved/staircase geometry and absorbing masked walls remain open.

The [rigid cylinder candidate](CYLINDER.md) adds a separate curved/staircase contract.
