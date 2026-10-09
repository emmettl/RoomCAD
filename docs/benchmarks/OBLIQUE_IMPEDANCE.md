# Damped oblique impedance source checks

The new source fixture pins an immutable ContinuumKit benchmark candidate.
Its [contract](https://github.com/emmettl/ContinuumKit/blob/main/docs/benchmarks/OBLIQUE_IMPEDANCE.md)
owns the independently solved complex box modes, roots, references, units and gates.
These are decaying mixed-axis modes with a real east impedance and rigid side walls,
not isolated real-angle pulses or measured-room validation. Existing benchmark pins,
cases and assertions remain unchanged.

RoomCAD compiles current verbatim CPU blocks and exact Metal kernels/Grid using the
existing source-binding script. Both run genuine nx×ny×4 domains with a guarded
z-mean plane. Physical pressure, both native face velocities and passive wall work
are captured completely. Initial nonzero wall flux is Taylor-expanded at its native
negative half clock; subsequent flux/work use actual old/new cell-pressure averages.
Complex incident/reflected amplitudes are fitted from the complete pressure history,
not from the imposed wall p/u ratio. Every pressure/velocity and loss metric has
separate spatial and temporal refinement gates. Continuum reference checks spatial
accuracy; matrix-exponential action on the fixed coupled x/y operator removes
spatial error from the time series. Production source, material/response policy and
tagged dependencies are unchanged.

Scripts/check-oblique.sh and the focused CI input `oblique` produce complete JSON/CSV
reports. The separate guard requires exact roots/cases/resolutions, captures and
native fields, individual field/work orders, fitted reflection and summary parity.
Full raw vectors are retained losslessly in private Edgerton. All workflows use the
physical Mac mini; full RoomCAD CI also runs its app and existing numerical suites.
No solver extraction or release is included. Masked/heterogeneous geometry, isolated
oblique pulses and frequency-dependent impedance remain separate work.
