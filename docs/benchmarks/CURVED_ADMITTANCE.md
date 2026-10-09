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
geometry failure is explicitly `gap`, never a physical pass. The original audit is
retained unchanged as evidence of the former full-staircase area bias. Current source
additionally requires all twelve records per backend to pass the same 0.5% physical
area gate through `Scripts/verify-wall-area.py`; a complete gap report now fails
application CI.

## Local area correction

For a locally planar surface of area A with unit normal n, the three Cartesian
staircase-face families have areas A|n_x|, A|n_y| and A|n_z|. Their sum is
A s, where s = |n_x| + |n_y| + |n_z|. Weighting each local face admittance by
1/s gives A in the resolved-plane limit. This follows from orthogonal projection;
it is a local geometry rule rather than an integrated cylinder calibration.

`WaveSolver.gridLayout` applies that weight to the nearest mesh face or plan wall,
including open faces with air impedance. Both CPU and Metal consume the same layout.
For axis-aligned normals the weight is exactly one. For unit normals it lies between
1/sqrt(3) and one, so coefficients stay non-negative. Rigid coefficients remain zero.
Cell occupancy, full-cell volume, interior fluxes and stepping kernels are unchanged.

`WallAreaTests` integrates actual original layout coefficients against independent
circle/rotated-square/tilted-cube areas. It checks mesh and plan forms, non-uniform
pressure with two side materials, air-impedance mesh openings, anisotropic spacing,
refinement and exact aligned-box coefficient parity. These prescribed-load checks do
not evolve a coupled acoustic field.

A staircase surface-area error is a known issue in room-acoustic FDTD; see the primary
[PFFDTD implementation notes](https://github.com/bsxfun/pffdtd#staircasing-in-fdtd).
That implementation describes a normal inner-product correction. The 1/s local
normalization here is independently derived above; no PFFDTD code is copied.

The correction reduces admittance-area bias; staircase location, corner assignment,
material discontinuities and reflected-wave errors remain. The next gate is an
independent **coupled absorbing-cylinder transient**, with separate spatial and temporal
refinement and full pressure/velocity/work histories. Passing area and a single local
substep is insufficient for that claim. AcousticCore remains application-owned;
no release tag, dependency pin or measured fixture changes are part of this work.
Durable complete evidence is retained privately in Edgerton.
