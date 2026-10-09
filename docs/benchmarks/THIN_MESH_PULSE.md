# Matched tilted thin-mesh pulse conformance

Extend the existing immutable xi=3 tilted pulse contract to the same physical room
represented by FloorPlan and RoomMesh.extruding. The independent continuum plane
reflection/causal-region and finite-domain damped-graph time/work references are
unchanged. Height is 0.00390625 m; space uses 64/128/256 lateral cells with two z
layers, and time fixes 64/64/2. Rigid caps and all native z velocities are checked.

The temporary source adapter binds actual current geometry/material layout, copied
CPU update blocks and Metal kernels for both representations. No production source
is rewritten. Retain whole native fields and every wall pressure, global/patch work,
original/scaled coefficients and clocks. Additional raw geometry diagnostics retain
material/normal-sample identities. Independently authored outward planes establish
every closed face's directed physical exit; unresolved mesh queries fail.

Run `bash Scripts/check-tilted-pulse.sh output` or dispatch suite `tilted-pulse` on
the physical mini. Original plan paths remain `cpu`/`metal`; new mesh paths are
`mesh/cpu`/`mesh/metal`. Both representations and backends pass the old independent
validator and are compared by `verify-tilted-pulse-pair.py`: all 24 records and both
axes must conform, and twelve full plan/mesh histories/errors/layouts must be exact.
This stricter pairing does not alter any oracle, fixture, threshold or release pin.

Numerical source equivalence and causal pulse verification do not establish general
mesh accuracy or measured material validity. Raw app-derived evidence remains in
private Edgerton; public Core may record aggregate findings. Source hashes are
compared with the preceding full application/eleven-suite mini checkpoint because
this change affects benchmark bindings and CI only.

## Physical-mini checkpoint, 9 October 2026

[Focused run 37948058999](https://github.com/emmettl/RoomCAD/actions/runs/37948058999)
passes the five independent controls, all 24 actual pulse records and twelve exact
plan/mesh pairs. Every source boundary and normal-sample identity matches the
independent plane oracle, with no unresolved crossing. Full native fields and
all-step wall traces, work, reflection/shift and errors are identical per backend.
All 31 AcousticCore hashes match full application run 37938336795; production
code and the original independent Core pin are unchanged.

Finest spatial pressure L2 is 2.57%, x velocity 2.00%, y velocity 7.12%. Reflection
is about 0.4572166 against 0.45700594, with a 1.24 mm pulse-coordinate lag. Time
refines at second order. Direct CPU/Metal maxima over every native field, all wall
traces and global/patch work are below 2.09e-6 in their declared amplitude/energy
normalizations (separate comparison bound 1e-4). Raw geometry and complete current
headers are retained privately; exact previous full histories are referenced with
canonical SHA-256/byte counts and a checked reconstruction script.
