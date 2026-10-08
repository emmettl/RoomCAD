# Axial acoustic source conformance

`Scripts/check-acoustics.sh OUTPUT` verifies the current unmasked CPU
velocity/pressure update blocks and coefficient declarations from
`Sources/AcousticCore/WaveSolver.swift`, copied verbatim into a generated serial
slab binding. The Metal fixture compiles the exact current embedded kernel source
and Grid layout from `MetalWaveSolver.swift`. A fully inside rigid box is supplied;
source injection, response normalization and audio processing are absent.

The plane pulse is uniform across a real N×4×4 grid. Captures average across the
transverse planes; row variation must remain below 1e-4 of pressure amplitude.
General/interior CPU arithmetic may produce Float32 row differences. Stored
pressure is normalized by density; the adapter converts between it and physical
Pa at the fixture boundary. Existing application source and package dependencies
remain unchanged. This checks the update kernels, not the entire response generator,
masked geometry, diffuse-decay correction or material-to-impedance conversion.

The fixture pins an immutable ContinuumKit benchmark candidate with shared
[cases and independent references](https://github.com/emmettl/ContinuumKit/blob/main/docs/benchmarks/ACOUSTICS.md).
Each backend must independently pass twelve runs covering axial travelling-pulse
and rigid-wall reflection with separate spatial/temporal refinements. CPU/GPU
agreement is not the accuracy oracle. Required Metal failure cannot fall back to CPU.

The physical Mac mini `acoustics` job verifies both backends and separately requires
complete JSON/CSV staggered fields, with 14-day artifacts. `make check` continues
to cover the application's existing contracts. BRAS physical validation remains
separate; acoustic source conformance does not replace it. Application-derived
multi-backend evidence is retained privately in Edgerton.
