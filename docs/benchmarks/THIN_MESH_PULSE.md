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
