# Curved masked wave conformance

`bash Scripts/check-cylinder.sh [output]` uses the immutable candidate in
`Fixtures/CylinderBenchmark` to compare actual masked CPU and Metal updates with
an independently authored radial/axial cylinder mode and continuous-time graph reference.
A closed 1024-sided cylindrical RoomMesh is classified by actual `WaveSolver.gridLayout`.
Its cell flags must exactly match independent circle membership at all declared grids;
all six active-cell face coefficients must match independently derived rigid connectivity.
The polygon is geometry input, while the stepped numerical boundary is the solver mask.

The temporary fixture follows the existing masked benchmark bindings: copy AcousticCore
verbatim, hash all 31 source files, use `@testable`/`-enable-testing`, bind actual
simulateMasked updates and exact Metal kernels, and retain all raw pressure/positive-face
velocities and actual masks. Inactive pressure starts at 100 Pa and must remain unchanged.
The application source, tagged dependencies, measured fixtures and existing gates remain
unchanged. Injection, receivers, decimation and complete response generation are separate.

Core's new cylinder contract separates staircase spatial error from time truncation.
All four fields are checked, with geometry volume, modified energy, blocked-face velocity
and inactive preservation gates. CI's `cylinder` choice also runs with `all` and requires
both CPU and real Metal. Full histories/layouts are retained as CI artifacts and durable
private Edgerton evidence. This establishes no measured or arbitrary-curved-room accuracy.

[Absorbing wall admittance audit](CURVED_ADMITTANCE.md) separates physical area from isolated wall-flow integration.
