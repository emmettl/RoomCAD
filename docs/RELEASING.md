# Local release preparation

`make app` builds an ad-hoc-signed `dist/RoomCAD.app`. `make release` prepares a
Developer ID-signed, Apple-notarized ZIP locally; it never creates a tag or uploads
an application release.

Use an existing Developer ID Application certificate/private key and a notarytool
Keychain profile on the release Mac. Set `ROOMCAD_SIGNING_IDENTITY` and
`ROOMCAD_NOTARY_PROFILE`; BombCAD environment variables are no longer fallback settings.
Keep `dev.roomcad.RoomCAD` and saved document/response identifiers stable. Update the
numeric version and positive build number in `Support/Info.plist`, commit, then run:

```sh
make release-check
make release
```

Preparation requires a clean checkout, runs lint/tests/release-script checks, builds
the app and verifies metadata, architecture, shaders, recordings, credits and licences.
It signs with the hardened runtime, submits to Apple, requires acceptance, staples and
validates the ticket, verifies signing and Gatekeeper, then creates the ZIP with a
checksum and source manifest. Existing archives are not overwritten. Review the
result before authorizing publication.

The historical signed 0.1.0 release and its original source/manifest remain at
[BombCAD's roomcad-v0.1.0 release](https://github.com/emmettl/bombcad/releases/tag/roomcad-v0.1.0).
The standalone repository preserves the filtered historical source tag, with a rewritten
commit ID recorded in the migration map. No historical binary, checksum or tag in
BombCAD is replaced, and no new application release is claimed by the repository split.
