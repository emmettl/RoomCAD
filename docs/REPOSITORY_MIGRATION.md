# Standalone RoomCAD repository — 8 October 2026

RoomCAD now lives at https://github.com/emmettl/RoomCAD. Its acoustic backend, audition,
documents, UI, measured fixtures, credited recordings and release tools remain together.
CAD foundations and response interchange use the exact public ContinuumKit
`0.1.0-alpha.2` release, resolved at `06841daecc26812706f8c686618aadb0cb6b7efa`.

The source checkpoint is BombCAD `285b620806418f39e4bc7a66be20191f2d366612`, followed
by the response adoption commit `b283a63653d0886af047b75e098bcaefa4462b1f`. Filtering
copies history into a new repository; no original BombCAD ref or worktree is rewritten.
The `RoomCAD/` prefix is removed. Four room-specific documentation files, LICENSE and
.gitignore retain their history as well. Author information and relevant ancestry are
preserved; hashes change because repository trees and parents change.

[Source hashes](history/split-source.json) record all 99 current application files and
verify byte parity immediately after filtering. [Commit mappings](history/bombcad-commit-map.txt)
connect original commits to rewritten commits, including the historical
`roomcad-v0.1.0` tag. Old full-repository dependency paths may be needed to build historical
checkouts; original sources and signed release artifacts remain available in BombCAD.

Administrative follow-up changes make paths and commands relative to the new root,
package the repository's own licence, give signing settings RoomCAD ownership and add
independent CI. No AcousticCore/Audition/RoomDocument/UI implementation, test assertion,
measured fixture, recording or saved-file identifier changes. Source comments that
name the old repository prefix remain historical context.

The nested application is retired in BombCAD only after standalone verification.
Its former documentation paths and package README become redirects. BombCAD's checks
then cover BombCAD; RoomCAD's dedicated Mac mini CI owns the standalone application.
