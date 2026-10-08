# Three-dimensional rigid-mode source verification

The new fixture consumes the immutable ContinuumKit benchmark candidate. Its
[contract](https://github.com/emmettl/ContinuumKit/blob/main/docs/benchmarks/RIGID_MODES_3D.md)
owns independent continuum/fixed-lattice references, units, resolutions and gates.
Prior axial and boundary fixtures keep their original pins and assertions.

RoomCAD compiles its current verbatim CPU blocks and exact embedded Metal source
using Scripts/prepare-boundary-reference.py. Both backends run full 3D domains,
with nonzero x/y/z velocities and native faces. One body-diagonal mode uses equal
cell spacing; the second grid has dz=2dx. Every pressure and velocity component
must independently show second-order spatial and temporal refinement, and satisfy
wall, accuracy and modified leapfrog energy checks. Physical pressure is converted
from production normalized pressure in the adapter. No z averaging or reduced
plane substitutes for full-volume fields. Production kernels, application source,
material policy and tagged dependencies are unchanged.

Scripts/check-rigid-3d.sh emits complete cases/results/conformance JSON and CSV.
The separate report guard requires the exact capability/resolution matrix, all
captures and native x/y/z shapes, recomputed individual field refinement orders,
finest bounds and exact summary values. Dense fields are retained losslessly in
private Edgerton. The focused CI suite is `rigid-3d`; full CI also runs this suite.
This is numerical verification, not measured validation or a solver release.
Masked geometry, heterogeneous media and oblique impedance remain separate work.
