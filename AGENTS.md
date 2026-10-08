# Working agreements

Preserve acoustic assumptions, saved document and response identifiers, fixture
provenance, dry-recording credits and original MIT attribution. Shared interchange
and CAD foundations are exact tagged dependencies in ContinuumKit; do not restore
local copies. AcousticCore and Audition remain application-owned.

Run `make check` for application changes. Rendering and wave verification require
actual Metal; the physical Mac mini runs `Scripts/ci-check.sh`, including packaging
and a headless snapshot. Do not weaken assertions or rewrite measured fixtures to
make a migration pass. Heavy BRAS validation is a separate `make validate` run.

Do not publish application releases without task authorization. Local release
preparation is documented in docs/RELEASING.md. Credential and Git metadata failures
inside a sandbox are inconclusive; retry narrow host access before diagnosing them.
