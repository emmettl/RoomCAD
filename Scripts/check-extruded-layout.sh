#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
output=${1:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-extruded-layout-output.XXXXXX")}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-extruded-layout-build.XXXXXX")
trap 'task_status=$?; rm -rf "$scratch"; exit "$task_status"' EXIT
mkdir -p "$output" "$scratch/consumer"
cp -R "$root/Fixtures/ExtrudedLayoutBenchmark/." "$scratch/consumer/"
cp -R "$root/Sources/AcousticCore" "$scratch/consumer/Sources/AcousticCore"
revision=$(cat "$root/Fixtures/ExtrudedLayoutBenchmark/core-revision.txt")
source=${CONTINUUMKIT_BENCHMARK_SOURCE:-https://github.com/emmettl/ContinuumKit.git}
git clone --no-checkout --quiet "$source" "$scratch/ContinuumKit"
git -C "$scratch/ContinuumKit" checkout --quiet "$revision"
python3 "$scratch/ContinuumKit/Scripts/benchmark-metadata.py" --root "$root" --repository https://github.com/emmettl/RoomCAD --precision Float32-layout --dependency "continuumkit=$revision" --output "$output/environment.json" "$root"/Sources/AcousticCore/*.swift Scripts/check-extruded-layout.sh Fixtures/ExtrudedLayoutBenchmark/Package.swift Fixtures/ExtrudedLayoutBenchmark/Sources/ExtrudedLayoutAdapter/Adapter.swift
swift run --package-path "$scratch/consumer" -c release -Xswiftc -enable-testing -Xswiftc -warnings-as-errors ExtrudedLayoutAdapter --cases "$scratch/ContinuumKit/Fixtures/ExtrudedLayout/cases.json" --output "$output"
python3 "$root/Scripts/evaluate-extruded-layout.py" --core "$scratch/ContinuumKit" --output "$output"
cp "$scratch/consumer/Package.resolved" "$output/consumer-Package.resolved"
