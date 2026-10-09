# Exact shared CPU/Metal benchmark binding

Run `bash Scripts/check-shared-waves.sh all output` for masked boxes, rigid cylinder,
curved admittance, absorbing cylinder and tilted plan/mesh pulses. The unchanged
original producer runs beside shared consumers at exact released version `0.1.0-alpha.6`.
The expected tag commit is retained alongside the version in `Fixtures/SharedWaveBenchmark`.
Actual RoomCAD geometry/material/normal preparation and original observation/scaling
code remain in the benchmark adapter; evolution uses Core's actual CPU/Metal steppers.
The application loop and its package pin, measured fixtures and original adapters remain unchanged.

Each shared consumer copies every original suite's BenchmarkSupport file byte-for-byte
from its immutable original Core revision into a temporary FrozenBenchmarkSupport
module. Its original pure thermodynamics dependency must also be source-identical.
This preserves every original oracle/validator body, even where newer Core versions
added dissipative capabilities to common graph helpers. Full source hashes and both
reference/implementation revisions are retained in every run. No frozen duplicate is
committed in RoomCAD; Core remains the authoritative source of those references.

The shared steppers receive actual prepared masks, six wall-term blocks, native
initial fields, timestep/spacing and physical density. They return normalized ψ and
positive-face velocities at complete-step clocks. Observation mirrors adapt these
snapshots to the existing pressure/wall-trace readers. Mirrors perform copies and
add cost; this is a numerical/source conformance gate, not a zero-copy or performance
comparison. Mirror buffers are never used for evolution, and GPU work is actual Metal.

Every original and shared run must pass the existing independent bounds. The additional
pair guard requires exact whole numerical/schema records, including every retained
native field, clock, layout, wall trace, global/patch work and error. All actual
AcousticCore hashes must agree. The tilted audit keeps every directed plane/material
identity, zero unresolved crossing and twelve exact plan/mesh pairs. Its only new
option explicitly selects the shared model-name namespace; default original names
and all numerical/geometry assertions stay unchanged.

Completion requires clean committed producer metadata, fetched exact implementation
pins, original frozen reference identities, complete original/shared reports and the
physical mini run. Raw application evidence stays private in Edgerton; public Core
may retain aggregate findings. This gate verifies the released steppers before production source-write,
receiver, cancellation and lifetime integration; the optimized box CPU path and
Edgerton's forced/damped 2D wave model remain separate contracts.

## Verified source-free checkpoint

Producer `9aaa91410e82d63ee9e7ceb73afc701bd3e7f068` passes the
[full physical-mini gate](https://github.com/emmettl/RoomCAD/actions/runs/38001607985):
96 exact original/shared records across all five suites and both backends, including
all 24 tilted plan/mesh records. Both producer and independent postcondition enforce
the complete count/tree. Original independent bounds and every retained numerical
/schema field are unchanged. Twelve exact tilted plan/mesh pairs preserve physical
wall identities and zero unresolved crossing. The earlier incomplete green run and
subsequent failed generator run are not conformance evidence.

Sixteen local schema/plane/producer controls cover wrong source fields/clocks/layouts,
missing velocity, wrong reference pin, early cleanup status and partial report trees.
The final addition after the tested producer contains only control tests/docs; model,
observer, generator and numerical validation bodies match the verified candidate.
Complete raw outputs and checked reconstruction are retained privately in Edgerton.

## Exact released dependency

Shared manifests now use SwiftPM `exact: version`; preparation checks the annotated
tag resolves to the reviewed commit. Both producer and independent postcondition
require every shared `Package.resolved` to contain that version and commit, and every
original consumer to retain its frozen reference revision. Three negative controls
reject a wrong version, wrong commit and revision-only resolution. The [full actual
CPU/Metal gate](https://github.com/emmettl/RoomCAD/actions/runs/38004414867) passed
on producer `33136177c27c589404f2b068f1c8545d0d7a0272`: all 96 complete exact pairs
and both producer/postcondition checks. All twelve retained resolved dependency
reports contain the exact released version and reviewed tag commit.
[Aggregate verification](shared-wave-alpha6-verification.json) records these identities;
complete downloaded reports and checked lossless reconstruction are retained privately
in Edgerton. The subsequent evidence documentation adds no numerical or adapter change.
