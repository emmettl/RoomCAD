# Shared wave-update preparation

Design checkpoint: 9 October 2026. The [proposed Core contract](https://github.com/emmettl/ContinuumKit/blob/main/docs/extraction/LINEAR_WAVE_UPDATE.md)
bounds the first move to a source-free serial masked complete step. A separate Metal
backend follows. This checkpoint changes documentation only: AcousticCore, production
loops, fixture identities, dependency pins and existing benchmarks stay in place.

## Pinned source boundary

The machine-readable [Core source map](https://github.com/emmettl/ContinuumKit/blob/main/docs/extraction/linear-wave-source.json)
pins RoomCAD `f2f6465d0d845af9adda596c004b18ca15a77edd`, including whole source files,
MIT attribution and bounded block hashes. Locations at that revision:

| Candidate block | Source location | First use |
| --- | --- | --- |
| Masked coefficients | `Sources/AcousticCore/WaveSolver.swift`, lines 613–622 | CPU descriptor; keep Double-to-Float preparation order |
| Masked velocity phase | Same file, lines 625–638 | Serial CPU step; positive-axis native faces |
| Masked pressure phase | Same file, lines 639–657 | Serial CPU step; six-face accumulation order |
| Swift Grid ABI | `Sources/AcousticCore/MetalWaveSolver.swift`, lines 43–48 | Later Metal backend, checked layout |
| Metal Grid ABI | Same file, lines 179–180 | Later Metal backend |
| `waveVelocity` | Same file, lines 182–195 | Later Metal backend |
| `wavePressure` | Same file, lines 198–218 | Later Metal backend |

These are selectors for extraction review, not instructions to copy the surrounding
classes. Grid/material layout, allocation/orchestration, source/receiver construction,
microphone combination, response bands and engine selection are outside these blocks.
Core's read-only verifier checks immutable Git objects; working app edits are neither
used nor modified. Record any deliberate port adaptation against the block hashes.

## App adapter and phase order

RoomCAD fields store ψ = pressure/density, not Pa. Its N-sized x/y/z velocity arrays
store the positive face of each cell, with zero closed/unused slots. The app must
prepare active masks and six blocks of β with the exact current geometry/material
and area convention. β is tied to the chosen timestep; Core must not infer ξ from
materials or reinterpret normals. Core uses the prepared mask/terms only.

The existing complete application step is:

1. Update live-link velocities from current ψ.
2. Complete the pressure divergence/wall update.
3. Inject `Float(pulse((n + 0.5) * dt)) * sourceWeight` into pressure; source weights
   already include `c² dt / cellVolume`.
4. Sample pressure and native velocities for the app's receiver/microphone contract.

Pressure is now at `(n + 1) * dt`; velocities are at `(n + 0.5) * dt`. The source-free
Core API initially cannot replace this whole loop. Before production adoption, design
safe CPU pressure writes and GPU source/receiver encoding with clear ownership and
completion clocks. Retain cancellation cadence, source scaling, receiver interpolation,
microphone staggering, batch behavior, device fallback policy and resource lifetimes.
Source work belongs to the app's energy ledger when forcing is introduced.

## Implementation paths and evidence

The masked CPU wrappers for masked domains, cylinders, admittance and tilted pulses
bind the chosen blocks using serial slabs. The optimized unmasked box path has a
different interior Float accumulation order; axial/boundary/rigid-3D/oblique CPU
evidence for that path does not substitute for direct masked port parity. Leave the
optimized path intact until a separately bounded task proves its own output contract.

The existing GPU wrappers bind the real update kernels. The first shared Metal
stepper owns resident buffers and waits for completion; it does not port `waveInject`,
`waveSample`, scheduling or whole `MetalWaveSolver`. ABI/resource and dispatch-hazard
tests require actual Metal on the physical mini.

The [full application/source checkpoint](https://github.com/emmettl/RoomCAD/actions/runs/37938336795)
and [thin-mesh pulse checkpoint](THIN_MESH_PULSE.md) remain the original baselines.
All 222 earlier wave histories and 24 matched pulse histories retain their private
payload identities. Core owns independent references, not app-derived raw reports.
Do not edit their tolerances, references or recorded results to fit a new backend.

## Adoption gates

First implement and independently test the serial Core CPU product; verify its
committed Git consumer without an app import or Metal requirement. Then bind an
exact candidate revision **beside** the original source adapter in a bounded RoomCAD
benchmark task. Compare complete fields, clocks, inactive/closed slots, every wall
trace, global/patch work and all applicable independent errors. Repeat actual GPU
gates when the separate Metal tranche is ready, including all 24 tilted plan/mesh
histories and twelve exact pairs.

Only after the source-write/receiver interface is designed and verified should a
separate production refactor replace an app loop. Run full `make check` / physical
mini CI for that application change, including packaged resources and rendering.
Release authorization and deliberate tested pins follow those gates. This design
adds no targets, implementation, app refactor or release.
