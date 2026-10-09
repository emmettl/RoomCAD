# Equivalent floor-plan and mesh assignment audit

The version-1 immutable Core geometry contract covers 18 convex extrusions with
rigid caps, aligned/tilted side walls, one or four absorbing side materials, two
lateral resolutions and three heights. Actual AcousticCore files are copied
verbatim into a temporary consumer. gridLayout provides whole native masks and
six coefficient arrays. Selected physical-face IDs repeat the current query for
diagnosis; the independent oracle uses directed convex-plane segment exits.

Run `bash Scripts/check-extruded-layout.sh /tmp/roomcad-extrusion` or dispatch the
`extruded-layout` suite on the physical Mac mini. The app regression now requires every declared layout to conform and every boundary
segment query to resolve. The independent oracle and tolerances are unchanged;
historical diagnostic gaps remain preserved. This geometry suite does not run wave updates.

Original audit results (before the directed selection fix): all 18 floor-plan layouts and 13 mesh layouts conform.
Five thin meshes (height 0.00390625 m) substitute rigid caps for absorbing side
walls: aligned nx=64 loses all 96 absorbing east faces, while tilted nx=32/64 loses
22/48 absorbing faces (admittance ratios 0.695815/0.661740). The mixed-material
variants lose the same east-face counts (total admittance ratios 0.859892/0.844569).
Identical plan/mesh masks, clocks and spacings isolate material assignment from
occupancy. Every thicker control passes. This is finite-grid layout evidence;
it does not measure acoustic decay or establish general mesh accuracy.

The directed selection fix uses the existing mesh ray query from each active cell
centre along the full active-to-inactive neighbour segment, bounded at its end with
a 1e-9 parameter tolerance. Wall materials and open-face air impedance
come from the crossed physical face. A full-height vertical extrusion between flat
caps retains the floor plan's closest-side normal for in-plane area quadrature,
excluding the caps from that measure. General meshes use the crossed-face normal.
The shape recognition uses only geometric normals and cap/side height bounds;
no material, resolution or named-case heuristic selects it. Masks, clocks, interior fluxes and update
kernels are unchanged. If an edge/degenerate query is unresolved, the existing
nearest-midpoint fallback remains; none of these certified extrusions uses it.

Local release adapter: all 36 layouts conform without fallback. Selected material
faces and normal-sample faces are retained separately. The original naive use of
crossed normals everywhere failed the unchanged coarse cylinder area gate (0.605%
error); preserving the extrusion's established in-plane measure resolves that
discretization change without altering any gate or reference. Four independent
Swift controls cover thin plan/mesh parity, open-side air, storage-order invariance
and a rotated thin slab with all six material impedances, independently scored
using local-box slab exits. Full physical-mini run [37938336795](https://github.com/emmettl/RoomCAD/actions/runs/37938336795)
passes at `fc9052528706c688ad8b2c22040ed09e5ee7351e`: 167 Swift tests, eight release
checks, actual Metal, release packaging/signature/snapshot and every existing
CPU/Metal wave/reflection/work suite. All 36 layouts pass without fallback. The
source tree includes upstream octave-band changes at `a1c0ae3`; this fix changes
only the two mesh geometry/layout files relative to that base. Release pins remain unchanged.

Nonconvex corners, degenerate imports and arbitrary openings are not certified by
these extrusion cases. The remaining nearest-midpoint fallback is an explicit
limit, not a general mesh-conformance guarantee.
