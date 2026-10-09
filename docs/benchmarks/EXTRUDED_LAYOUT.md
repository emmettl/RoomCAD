# Equivalent floor-plan and mesh assignment audit

The version-1 immutable Core geometry contract covers 18 convex extrusions with
rigid caps, aligned/tilted side walls, one or four absorbing side materials, two
lateral resolutions and three heights. Actual AcousticCore files are copied
verbatim into a temporary consumer. gridLayout provides whole native masks and
six coefficient arrays. Selected physical-face IDs repeat the current query for
diagnosis; the independent oracle uses directed convex-plane segment exits.

Run `bash Scripts/check-extruded-layout.sh /tmp/roomcad-extrusion` or dispatch the
`extruded-layout` suite on the physical Mac mini. This geometry audit deliberately
retains complete `conformance-gap` results and fails on malformed topology or an
incomplete case matrix. It does not run wave updates or change production source.

Local candidate results: all 18 floor-plan layouts and 13 mesh layouts conform.
Five thin meshes (height 0.00390625 m) substitute rigid caps for absorbing side
walls: aligned nx=64 loses all 96 absorbing east faces, while tilted nx=32/64 loses
22/48 absorbing faces (admittance ratios 0.695815/0.661740). The mixed-material
variants lose the same east-face counts (total admittance ratios 0.859892/0.844569).
Identical plan/mesh masks, clocks and spacings isolate material assignment from
occupancy. Every thicker control passes. This is finite-grid layout evidence;
it does not measure acoustic decay or establish general mesh accuracy.

The bounded follow-up is directed wall selection in actual gridLayout, preserving
area weights and masks, with these cases becoming strict regressions and the
existing CPU/Metal field/work suites rerun. Release pins remain unchanged.
