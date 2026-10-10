#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
output=${1:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-acoustic-output.XXXXXX")}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-acoustic-build.XXXXXX")
trap 'task_status=$?; rm -rf "$scratch"; exit "$task_status"' EXIT
mkdir -p "$output" "$scratch/consumer"
cp -R Fixtures/AcousticBenchmark/. "$scratch/consumer/"
python3 Scripts/prepare-acoustic-reference.py --root "$root" --output "$scratch/consumer/Sources/AcousticAdapter"
revision=$(cat Fixtures/AcousticBenchmark/core-revision.txt)
source=${CONTINUUMKIT_BENCHMARK_SOURCE:-https://github.com/emmettl/ContinuumKit.git}
git clone --no-checkout --quiet "$source" "$scratch/ContinuumKit"
git -C "$scratch/ContinuumKit" checkout --quiet "$revision"
export CONTINUUMKIT_BENCHMARK_SOURCE="$scratch/ContinuumKit"
for backend in cpu metal; do
 mkdir -p "$output/$backend"
 python3 "$scratch/ContinuumKit/Scripts/benchmark-metadata.py" --root "$root" \
  --repository https://github.com/emmettl/RoomCAD --precision Float32 --dependency "continuumkit=$revision" \
  --output "$output/$backend/environment.json" Sources/AcousticCore/WaveSolver.swift Sources/AcousticCore/WaveGridLayout.swift Tests/AcousticCoreTests/OriginalMetalWaveSolver.swift Fixtures/OriginalWaveReference/metal-source.json Fixtures/OriginalWaveReference/MetalWaveSolver.swift.gz Scripts/original_wave_reference.py \
  Scripts/prepare-acoustic-reference.py Fixtures/AcousticBenchmark/Sources/AcousticAdapter/Adapter.swift
 swift run --package-path "$scratch/consumer" -c release -Xswiftc -warnings-as-errors AcousticAdapter \
  --backend "$backend" --output "$output/$backend" --metadata "$output/$backend/environment.json"
 python3 "$scratch/ContinuumKit/Scripts/verify-acoustic-output.py" "$output/$backend"
 cp "$scratch/consumer/Package.resolved" "$output/$backend/consumer-Package.resolved"
done
