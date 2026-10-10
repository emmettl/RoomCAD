# Protected original affine fitting compile controls

The complete RoomParameters.swift and DecayAnalysis.swift files are retained from
RoomCAD bf869284f29b7604a08d98cf66cf8a2c5619e525, before alpha.18 numerical adoption.
Their immutable Git blobs, original SHA-256, byte counts and lossless gzip hashes
are recorded in source.json and checked by Scripts/original_fitting_reference.py.
The two numerical-loop identities are the same as the earlier Core fitting audit.
Original MIT attribution remains unchanged.

Frozen pre-alpha.18 verification consumers need these source files because their
Core pins do not expose Numerics. The copier writes only into temporary verification
modules and rejects production destinations. Cases, original reference pins,
coefficient bounds and model/unsupported labels remain unchanged. Production uses
the shared Numerics product; this control does not restore a production duplicate.

Four tests cover exact copying, production rejection, immutable identity corruption
and changed numerical source even with a coherent compressed hash. The independent
current-application affine adoption gate remains separate from original arithmetic
and historical FFT conformance; old inaccurate fitting coefficients remain findings.
