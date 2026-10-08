# Mixed-axis and impedance source checks

Scripts/check-boundaries.sh compiles current production calculations in a temporary
consumer of the immutable core benchmark candidate. Production sources and tagged
application dependencies are unchanged. Core owns the independent continuum and
fixed-lattice references, gates and complete field/report contract:
https://github.com/emmettl/ContinuumKit/blob/main/docs/benchmarks/ACOUSTIC_BOUNDARIES.md

The mixed-axis rigid modes exercise both x/y gradients and normal velocities.
These are standing superpositions at 45 and 26.565 degrees, not oblique absorbing
reflection. RoomCAD supplies a real N×Ny×4 grid and a guarded z-mean plane. Its
actual semi-implicit east-face coefficients support matched, positive and inverted
normal reflections. The boundary flux is reconstructed from actual old/new cell
pressure averages and its passive work is accumulated each step. Edgerton has no
production impedance law: all three such cases are explicitly unsupported.

No unsupported record is a passing numerical case. A separate CI guard requires
the complete capability matrix, cases, resolutions, native staggered fields and
matching CSV summary. Native fields and source hashes are retained; large dense
JSON evidence is losslessly compressed in private Edgerton.

The impedance gate checks full-field accuracy, signed reflection, returned energy,
work closure, at-least-first-order mixed spatial convergence and bounded half-step
sensitivity. The additional fixed 192×4 lattice series now checks independent second-order
pressure and cumulative-loss time refinement against the core matrix-exponential
reference, at nominal Courant numbers 0.6/0.3/0.15. Spatial reflection gates and
the old sensitivity check remain. Material
mapping, openings, body-diagonal 3D and oblique impedance remain outside scope.
