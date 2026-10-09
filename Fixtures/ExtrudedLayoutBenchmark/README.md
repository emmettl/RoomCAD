# Actual source extrusion geometry audit

Copies all AcousticCore sources verbatim into a temporary consumer. Executes actual
WaveSolver.gridLayout for equivalent FloorPlan and RoomMesh.extruding inputs, with
rigid caps, two lateral grids, three heights and two side-material configurations.
The Core contract uses independent convex half-spaces and directed segment exits.
Selected face IDs are explanatory diagnostics obtained by repeating the source's
current nearest-face queries; the actual coefficient arrays come from gridLayout.

Geometry-only: no time evolution, CPU/Metal backend comparison or wave accuracy claim.
A complete audit with assignment gaps succeeds diagnostically and retains
`conformance-gap`; missing/malformed layouts or wrong topology fail. New numerical
extraction or a production fix requires its own task and regression evidence.
