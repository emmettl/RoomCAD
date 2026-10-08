#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
output=${1:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-rigid-3d-output.XXXXXX")}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-rigid-3d-build.XXXXXX")
trap 'task_status=$?; rm -rf "$scratch"; exit "$task_status"' EXIT
mkdir -p "$output" "$scratch/consumer"
cp -R Fixtures/Rigid3DBenchmark/. "$scratch/consumer/"
python3 Scripts/prepare-boundary-reference.py --root "$root" --output "$scratch/consumer/Sources/Rigid3DAdapter"
revision=$(cat Fixtures/Rigid3DBenchmark/core-revision.txt)
source=${CONTINUUMKIT_BENCHMARK_SOURCE:-https://github.com/emmettl/ContinuumKit.git}
git clone --no-checkout --quiet "$source" "$scratch/ContinuumKit"
git -C "$scratch/ContinuumKit" checkout --quiet "$revision"
export CONTINUUMKIT_BENCHMARK_SOURCE="$scratch/ContinuumKit"
for backend in cpu metal; do
 mkdir -p "$output/$backend"
 python3 "$scratch/ContinuumKit/Scripts/benchmark-metadata.py" --root "$root" \
  --repository https://github.com/emmettl/RoomCAD --precision Float32 --dependency "continuumkit=$revision" \
  --output "$output/$backend/environment.json" Sources/AcousticCore/WaveSolver.swift Sources/AcousticCore/MetalWaveSolver.swift \
  Scripts/prepare-boundary-reference.py Scripts/check-rigid-3d.sh Fixtures/Rigid3DBenchmark/Sources/Rigid3DAdapter/Adapter.swift
 swift run --package-path "$scratch/consumer" -c release -Xswiftc -warnings-as-errors Rigid3DAdapter \
  --backend "$backend" --output "$output/$backend" --metadata "$output/$backend/environment.json"
 python3 "$scratch/ContinuumKit/Scripts/verify-rigid-3d-output.py" "$output/$backend"
 cp "$scratch/consumer/Package.resolved" "$output/$backend/consumer-Package.resolved"
done
