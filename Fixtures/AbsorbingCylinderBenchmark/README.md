# Actual-source coupled absorbing-cylinder adapter

Pins an immutable independent ContinuumKit candidate. The temporary package copies
all AcousticCore source verbatim, binds actual simulateMasked coefficient/update
blocks, and dispatches actual waveVelocity/wavePressure Metal kernels. No substitute
integrator, source injection, receiver, diffuse-decay fitting or application minimum
volume policy is used in this bounded numerical case.

The actual mesh/material/gridLayout creates the mask and wall coefficients. Original
and benchmark-clock-scaled arrays and clocks are retained. Every wall pressure at
every complete step is retained, with complete native p/u/v/w captures and midpoint
wall work. Spatial fields/work compare to the continuum Robin Bessel mode. Time
compares to an independent continuous graph assembled from audited fixed spatial
coefficients. Existing fixture pins and production dependencies remain unchanged.
