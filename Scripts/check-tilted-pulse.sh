#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
python3 Scripts/test-tilted-pulse-pair.py
output=${1:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-tilted-pulse-output.XXXXXX")}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-tilted-pulse-build.XXXXXX")
trap 'task_status=$?; rm -rf "$scratch"; exit "$task_status"' EXIT
mkdir -p "$output" "$scratch/consumer"
cp -R Fixtures/TiltedPulseBenchmark/. "$scratch/consumer/"
python3 Scripts/prepare-tilted-pulse-reference.py --root "$root" --output "$scratch/consumer"
revision=$(cat Fixtures/TiltedPulseBenchmark/core-revision.txt)
source=${CONTINUUMKIT_BENCHMARK_SOURCE:-https://github.com/emmettl/ContinuumKit.git}
git clone --no-checkout --quiet "$source" "$scratch/ContinuumKit"
git -C "$scratch/ContinuumKit" checkout --quiet "$revision"
export CONTINUUMKIT_BENCHMARK_SOURCE="$scratch/ContinuumKit"
for representation in plan mesh; do
 for backend in cpu metal; do
  directory="$output/$backend"
  if test "$representation" = mesh; then directory="$output/mesh/$backend"; fi
  mkdir -p "$directory"
  python3 "$scratch/ContinuumKit/Scripts/benchmark-metadata.py" --root "$root" \
   --repository https://github.com/emmettl/RoomCAD --precision Float32 --dependency "continuumkit=$revision" \
   --output "$directory/environment.json" Sources/AcousticCore/*.swift \
   Scripts/prepare-tilted-pulse-reference.py Scripts/check-tilted-pulse.sh Scripts/verify-tilted-pulse-pair.py Scripts/test-tilted-pulse-pair.py Fixtures/TiltedPulseBenchmark/Sources/TiltedPulseAdapter/Adapter.swift
  swift run --package-path "$scratch/consumer" -c release -Xswiftc -enable-testing -Xswiftc -warnings-as-errors TiltedPulseAdapter \
   --backend "$backend" --representation "$representation" --output "$directory" --metadata "$directory/environment.json"
  python3 "$scratch/ContinuumKit/Scripts/verify-tilted-pulse-output.py" "$directory"
  cp "$scratch/consumer/Package.resolved" "$directory/consumer-Package.resolved"
 done
done
python3 Scripts/verify-tilted-pulse-pair.py "$output"
