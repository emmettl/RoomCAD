# Actual masked wall admittance audit

`bash Scripts/check-admittance.sh [output]` audits both actual CPU and Metal updates
against the immutable independent core contract in `Fixtures/AdmittanceBenchmark`.
The aligned-box control and 1024-sided cylinder use absorbing side materials and rigid
caps. The independent ξ=3 statistical absorption input is passed through the actual
material-to-impedance conversion; measured impedance must match the declared contract.
Actual `gridLayout` masks must match independent shape membership. Original face arrays
and solver layout clock are retained; positive wall coefficients are linearly rescaled
to the benchmark timestep and both sets are verified. Application decimation, injection
and receiver policy, including the application minimum room volume, are excluded from this isolated wall-flow calibration.

All AcousticCore sources are copied verbatim and hashed, with temporary @testable access
and actual simulateMasked blocks/Metal kernels. Full p/u/v/w fields at steps 0/1 and
all original/rescaled faces are retained. The numerical wall substep has an independent
exponential reference, rate refinement and pressure-loss/midpoint-wall-work checks.
This verifies the first local flow substep, not an entire absorbing-cylinder transient.

Physical prescribed-load admittance is audited separately against real side area. A
geometry failure is explicitly `gap`, never a physical pass. CI verifies complete reports
and numerical contracts while preserving that gap; fixing the layout is separate bounded
numerical work. No production sources, tagged dependencies, old gates or measured fixtures
are changed. Durable complete evidence is retained privately in Edgerton.
