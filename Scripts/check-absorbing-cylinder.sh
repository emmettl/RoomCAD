#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
output=${1:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-absorbing-cylinder-output.XXXXXX")}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-absorbing-cylinder-build.XXXXXX")
trap 'task_status=$?; rm -rf "$scratch"; exit "$task_status"' EXIT
mkdir -p "$output" "$scratch/consumer"
cp -R Fixtures/AbsorbingCylinderBenchmark/. "$scratch/consumer/"
python3 Scripts/prepare-absorbing-cylinder-reference.py --root "$root" --output "$scratch/consumer"
revision=$(cat Fixtures/AbsorbingCylinderBenchmark/core-revision.txt)
source=${CONTINUUMKIT_BENCHMARK_SOURCE:-https://github.com/emmettl/ContinuumKit.git}
git clone --no-checkout --quiet "$source" "$scratch/ContinuumKit"
git -C "$scratch/ContinuumKit" checkout --quiet "$revision"
export CONTINUUMKIT_BENCHMARK_SOURCE="$scratch/ContinuumKit"
for backend in cpu metal; do
 mkdir -p "$output/$backend"
 python3 "$scratch/ContinuumKit/Scripts/benchmark-metadata.py" --root "$root" \
  --repository https://github.com/emmettl/RoomCAD --precision Float32 --dependency "continuumkit=$revision" \
  --output "$output/$backend/environment.json" Sources/AcousticCore/*.swift Tests/AcousticCoreTests/OriginalMaskedCPU.swift Tests/AcousticCoreTests/OriginalMetalWaveSolver.swift Fixtures/OriginalWaveReference/metal-source.json Fixtures/OriginalWaveReference/MetalWaveSolver.swift.gz \
  Fixtures/OriginalWaveReference/masked-cpu-source.json Fixtures/OriginalWaveReference/WaveSolver.swift.gz \
  Scripts/original_wave_reference.py Scripts/original_fft_reference.py Fixtures/OriginalFFTReference/source.json Fixtures/OriginalFFTReference/RealFFT.swift.gz \
  Scripts/prepare-absorbing-cylinder-reference.py Scripts/check-absorbing-cylinder.sh Fixtures/AbsorbingCylinderBenchmark/Sources/AbsorbingCylinderAdapter/Adapter.swift
 swift run --package-path "$scratch/consumer" -c release -Xswiftc -enable-testing -Xswiftc -warnings-as-errors AbsorbingCylinderAdapter \
  --backend "$backend" --output "$output/$backend" --metadata "$output/$backend/environment.json"
 python3 "$scratch/ContinuumKit/Scripts/verify-absorbing-cylinder-output.py" "$output/$backend"
 cp "$scratch/consumer/Package.resolved" "$output/$backend/consumer-Package.resolved"
done
