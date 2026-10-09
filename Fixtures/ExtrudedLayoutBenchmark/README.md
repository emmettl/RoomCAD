# Actual source extrusion geometry audit

Copies all AcousticCore sources verbatim into a temporary consumer. Executes actual
WaveSolver.gridLayout for equivalent FloorPlan and RoomMesh.extruding inputs, with
rigid caps, two lateral grids, three heights and two side-material configurations.
The Core contract uses independent convex half-spaces and directed segment exits.
Selected face IDs repeat the source's directed segment query; actual coefficients
come from gridLayout. Unresolved crossings are retained explicitly and must be empty
for every declared extrusion.

Geometry-only: no time evolution, CPU/Metal backend comparison or wave accuracy claim.
All 36 declared layouts must conform, using the unchanged independent oracle and
tolerances. Any assignment gap, malformed topology or fallback query fails the app
regression. Historical diagnostic gaps remain retained in the private checkpoint.
The contract pin is the geometry oracle/case matrix; the temporary Swift consumer
uses released ImpulseResponseKit 0.1.0-alpha.2 and retains Package.resolved.

Material face identities and normal-sample identities are retained separately.
Full-height vertical extrusions use closest in-plane side normals for the existing
floor-plan area quadrature; general meshes use crossed-face normals. Shape recognition
checks full side heights and two flat cap levels. No declared case uses the legacy
nearest-midpoint fallback.
