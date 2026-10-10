# Complete real FFT application adoption

`Scripts/check-fft-adoption.sh` compares protected RoomCAD 2bc11ed6 (alpha.12)
with the committed candidate (exact alpha.17). The same committed fixture is
compiled optimized against both packages, with testable internal application APIs.
Original production code and pins are unchanged by setup.

All 84 case outputs are retained: 16 full band renderings, 48 rendered/measured
band/decay histories, six response comparisons, eight whole production dry-clip
previews and every stereo wet/dry/mix sample, four complete generated responses
and two two-driver validation-scene responses. The two sample rates are 8/48 kHz;
parameters, arrival gains, complete input/output arrays and scalar metrics remain
explicit. The authored scene is numerical conformance, not measured validation.
Wave-enabled CPU/Metal integration remains covered by the existing production gates.

Each JSON vector points into `native.bin` with count, native precision, byte offset
and SHA-256. The full little-endian IEEE754 payload is lossless values/bits, rather
than large duplicated decimal and hex strings. No samples are discarded. The
checker validates complete buffer coverage and dimensions, exact old/new arrays,
independent complete Schroeder/fitting, full sparse time-domain convolution,
preview energy/peaks and every output mix. Ten deliberate paired corruptions reject
including forged native checksums. Core's released independent scalar DFT/inverse,
packing, gains and circular-filter suite supplies the primitive numerical gate.
