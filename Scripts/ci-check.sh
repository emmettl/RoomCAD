#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
output=${ROOMCAD_CI_OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-ci.XXXXXX")}
mkdir -p "$output"
exec > >(tee "$output/check.log") 2>&1

git rev-parse HEAD
swift --version
python3 Scripts/verify-original-wave-reference.py --require-git
swift Scripts/check-metal.swift
make check
bash Scripts/build-app.sh release
codesign --verify --deep --strict dist/RoomCAD.app
python3 Scripts/verify-original-wave-reference.py --product-binary dist/RoomCAD.app/Contents/MacOS/RoomCAD
dist/RoomCAD.app/Contents/MacOS/RoomCAD --snapshot "$output/roomcad.png"
if test -n "$(git status --porcelain)"; then
    echo "CI changed the checkout; review source or fixture changes." >&2
    git status --short
    exit 1
fi
echo "RoomCAD standalone checks and packaged snapshot passed."
