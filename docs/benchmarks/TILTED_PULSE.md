# Actual source isolated tilted-plan pulse

`bash Scripts/check-tilted-pulse.sh [output]` binds actual AcousticCore CPU masked
coefficient/update blocks and actual Metal wave kernels to the immutable independent
Core contract in `Fixtures/TiltedPulseBenchmark`. A z-invariant thin plan has one tilted
xi=3 wall, rigid other walls/caps and a compact incoming x pulse. All 31 production
sources are copied verbatim and hashed; no source stepper is replaced.

Actual material conversion, plan occupancy, nearest-wall selection and original
face coefficients/clock are retained. The solver uses 768,000 Hz for a stable original
layout clock; coefficients are linearly rescaled to independently selected benchmark
space/time clocks. The GPU receives all three actual grid spacings. Injection,
receivers, decay fitting, decimation and minimum-volume policy are excluded.

Complete native fields are retained. Physical plane accuracy uses only the declared
central causal region with a fixed wall clearance, before finite-end returns can
reach it. Spatial reference values outside that region are analytic extensions.
Echo amplitude and bounded template shift are fitted separately after the incident
pulse leaves that region. Global blocked/inactive/z-motion and exact initialization
checks still cover every field element. Every source wall pressure at every step is
retained, so total/central-patch midpoint work and modified global energy are audited
independently. The smooth patch is a measurement window, not a wave envelope.

Fixed-graph time refinement includes the finite plan and its corner response; an
independently verified z reduction and exponential/polynomial work reference isolate
stepping from geometry. A spatial physical failure reports gap; report integrity and
numerical time/energy CI can pass with that explicit gap, without claiming conformance.
No older fixture, gate, dependency pin, production source or release tag is changed.
Complete raw evidence stays private in Edgerton. General mesh/thin-cap face selection,
other incidence angles/materials and measured acoustics remain separate work.
