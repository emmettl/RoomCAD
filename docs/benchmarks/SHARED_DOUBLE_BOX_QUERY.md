# Shared Double box-query adoption

RoomCAD uses `SceneModel.BoxQuery.intersection` for fitted-zone traversal. The
shared primitive operates on explicit Double bounds and never converts to the
persisted Float Box. Thin translated zones retain their extent. RoomCAD retains
its stationary-point convention and requires positive traversal length: a closed
geometric touch contributes no attenuation. Density, absorption, scattering,
ordering, path timing, room acceptance and all mesh/BVH queries remain app-owned.

The protected producer is RoomCAD `7d73614`; the original FittingZone source SHA-256
is `16a7ba8f2610b707bfa24fbbeec914ad34b2910fbdfb8dbdf08390982db219f6`.
`SharedBoxQueryTests` contains its exact original overlap body, with a script guard
checking that body against Git. Thirteen thousand five hundred finite bounded
ray/segment/stationary cases compare both complete endpoint bit patterns; contact,
zero-length, stationary and actual optical-depth controls also pass. Existing
image-source/ray/direct attenuation tests remain unchanged.

The migration adds SceneModel to AcousticCore's declared dependencies and pins
an exact published Core version. The earlier alpha18 affine evidence keeps its
original producer/pin and frozen assertions. The active affine, wave, FFT and
response sources are checked byte-for-byte against accepted alpha18; later released
CAD portability and default-preserving zoom changes are covered by the new package
and application checks rather than relabelled as old capture evidence. New query
and adapter identities are exact and deliberate corruptions reject.

Before publication, the two adoption tests and complete `make check` (211 Swift
tests plus Python reference/release checks and build) passed on the M4 Max using a
temporary edited dependency. Exact-version physical-host app/package/snapshot
acceptance is recorded separately after publication. No empirical acoustic accuracy,
performance improvement or IFC-import feature is implied by this adoption.

IFC metadata, part hierarchy and converter diagnostics remain good future sharing
candidates. The current BombCAD importer still joins these to structural selection,
reinforcement and shell conversion. An acoustic interior/enclosure adapter and a
concrete RoomCAD IFC workflow must precede that broader extraction. BombCAD's
existing released Float spatial queries require no change for this Double API.

## Accepted exact-version integration

Both physical Macs pass 211 Swift tests, all `make check` reference/release checks,
actual Metal, packaging/strict signatures and inspected headless snapshots at exact
ContinuumKit alpha.23. The [mini adoption run](https://github.com/emmettl/RoomCAD/actions/runs/38539563278)
passes all sixteen application/current-wave/frozen-reference/capture jobs.
Current CPU comparisons retain 36,696 samples; Metal retains 45,144. Nine minimal
box/plan/mesh scenes retain 90 full runs and 45,144 samples per backend, with the
independent two-step observation oracle. All report corruption controls pass.
Frozen extrusion retains all 36 layouts without fallback or weakened bounds.

[Source-bound acceptance](shared-double-box-query-verification.json) records the
verified `b96f542` producer, immutable Core pin, source identities, both inspected
snapshots and complete job/log identities. Earlier alpha18 fitting captures retain
that exact Core pin and the protected original query compile dependency; they are
not relabelled as current alpha23 numerical evidence. This final record changes
README/documentation only; production, tests, fixtures, scripts and resolved pin
remain byte-identical to the accepted producer. No RoomCAD application release
is published by this integration.
