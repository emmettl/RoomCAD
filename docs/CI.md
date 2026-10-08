# CI on the physical Mac mini

RoomCAD has its own repository-scoped runner, `mac-mini-roomcad`, installed at
`~/Developer/roomcad-runner` on the Apple M4 Mac mini reached through SSH alias
`scrimply-ci-tb` (fallback `scrimply-ci-lan`). Labels are `self-hosted`, `macOS`,
`ARM64`, `metal`, `roomcad`. The verified initial runner is 2.338.0; Xcode provides
Swift 6.4. Its launch agent starts at user login. Keep the mini signed in and awake.

Check runs on main pushes and manual dispatch, using only the RoomCAD-labelled runner.
External fork workflow runs require approval for all contributors. No automatic
pull-request execution is enabled on this host. The `roomcad-metal` concurrency group
lets active runs finish; other repositories have their own runner registrations.

`Scripts/ci-check.sh` verifies an actual Metal dispatch and all 256 outputs, strict
formatting, the complete RoomCAD test suites, eight release-script tests and debug
build. It then builds and ad-hoc signs the release app, checks its deep strict signature,
and renders a headless packaged snapshot. This covers shader and recording bundle
lookup from the standalone package. A source or fixture change during CI fails the run.

Logs and the snapshot live outside the checkout in the runner temporary directory
and are retained for 14 days as job artifacts. Heavy measured-room comparisons remain
explicit `make validate` runs; concurrent GPU timings are not performance thresholds.
Application signing/notarization remains local release preparation.

Service operations on the mini:

```sh
cd ~/Developer/roomcad-runner
./svc.sh status
./svc.sh stop
./svc.sh start
```

Local reproduction from a clean checkout:

```sh
ROOMCAD_CI_OUTPUT_DIR=/private/tmp/roomcad-ci-logs bash Scripts/ci-check.sh
```

Do not log registration tokens or copy another runner's credentials. A replacement
runner must use the official macOS ARM64 archive, verify the published digest and
register with a fresh repository-scoped temporary token. Dispatch Check and inspect
both the selected runner and actual Metal verification output.
