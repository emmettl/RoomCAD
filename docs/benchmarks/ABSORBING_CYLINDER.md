# Actual-source coupled absorbing-cylinder verification

`bash Scripts/check-absorbing-cylinder.sh [output]` runs the immutable independent
Core contract pinned in `Fixtures/AbsorbingCylinderBenchmark` on actual CPU and
Metal numerical updates. One ξ=3 circular cylinder has rigid caps and compatible
complex Robin Bessel initial data. Separate space/time refinement checks complete
native pressure and all three staggered velocities, physical side area, shape volume,
initial preparation, blocked faces, inactive sentinels and cumulative wall work.

Every AcousticCore source is copied verbatim and hashed. The temporary CPU binding
uses actual simulateMasked coefficient/update blocks; Metal uses actual source kernels
and requires completed commands on a real device. Mesh/material/gridLayout output is
retained as original flags/face arrays and clock, then coefficients are linearly scaled
to the benchmark clock. Material conversion is actual; measured ξ must match the
independently chosen statistical absorption input. Source injection, receivers,
diffuse-decay fitting, decimation and minimum room-volume policy are excluded.

All source wall-cell pressures at every complete step are retained in Pa. An
independent Python audit reconstructs midpoint wall work from that trace and checks
capture ledgers and the modified leapfrog energy identity. It restores exact IEEE
Float32 coefficients before auditing layout power and work. The Swift independent
reference computes complete field norms: continuum Bessel fields/work for spatial
refinement, and a continuous-time damped graph for timestep refinement on fixed
actual audited geometry. The graph reference is separate from production stepping.

This benchmark verifies one bounded numerical mode, not measured room accuracy,
arbitrary materials, curved pulse reflection or general mesh conformance. Existing
rigid-cylinder, admittance, response fixtures and numerical gates remain unchanged.
No AcousticCore, package dependency, application source or release tag changes here.
Complete app-derived evidence is retained privately in Edgerton after physical CI.
