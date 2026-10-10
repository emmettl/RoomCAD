#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
output=${1:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-extruded-layout-output.XXXXXX")}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-extruded-layout-build.XXXXXX")
trap 'task_status=$?; rm -rf "$scratch"; exit "$task_status"' EXIT
mkdir -p "$output" "$scratch/consumer"
cp -R "$root/Fixtures/ExtrudedLayoutBenchmark/." "$scratch/consumer/"
# Frozen geometry fixture predates production wave APIs. Copy every original app file
# verbatim, omitting only the separately verified optional shared simulation backend.
python3 - "$root" "$scratch" <<'COPY_SOURCES'
import shutil, sys
from pathlib import Path
root, scratch = map(Path, sys.argv[1:])
sys.path.insert(0, str(root / 'Scripts'))
from original_wave_reference import copy_original_masked_reference
shutil.copytree(root / 'Sources/AcousticCore', scratch / 'consumer/Sources/AcousticCore',
                ignore=shutil.ignore_patterns('SharedWaveSimulation.swift', 'SharedMetalSimulation.swift'))
copy_original_masked_reference(root, scratch / 'consumer/Sources/AcousticCore')
COPY_SOURCES
revision=$(cat "$root/Fixtures/ExtrudedLayoutBenchmark/core-revision.txt")
source=${CONTINUUMKIT_BENCHMARK_SOURCE:-https://github.com/emmettl/ContinuumKit.git}
git clone --no-checkout --quiet "$source" "$scratch/ContinuumKit"
git -C "$scratch/ContinuumKit" checkout --quiet "$revision"
python3 "$scratch/ContinuumKit/Scripts/benchmark-metadata.py" --root "$root" --repository https://github.com/emmettl/RoomCAD --precision Float32-layout --dependency "continuumkit=$revision" --output "$output/environment.json" Sources/AcousticCore/*.swift Tests/AcousticCoreTests/OriginalMaskedCPU.swift Tests/AcousticCoreTests/OriginalMetalWaveSolver.swift Fixtures/OriginalWaveReference/metal-source.json Fixtures/OriginalWaveReference/MetalWaveSolver.swift.gz Fixtures/OriginalWaveReference/masked-cpu-source.json Fixtures/OriginalWaveReference/WaveSolver.swift.gz Scripts/original_wave_reference.py Scripts/check-extruded-layout.sh Scripts/evaluate-extruded-layout.py Fixtures/ExtrudedLayoutBenchmark/core-revision.txt Fixtures/ExtrudedLayoutBenchmark/Package.swift Fixtures/ExtrudedLayoutBenchmark/Sources/ExtrudedLayoutAdapter/Adapter.swift
swift run --package-path "$scratch/consumer" -c release -Xswiftc -enable-testing -Xswiftc -warnings-as-errors ExtrudedLayoutAdapter --cases "$scratch/ContinuumKit/Fixtures/ExtrudedLayout/cases.json" --output "$output"
python3 "$root/Scripts/evaluate-extruded-layout.py" --core "$scratch/ContinuumKit" --output "$output"
cp "$scratch/consumer/Package.resolved" "$output/consumer-Package.resolved"
