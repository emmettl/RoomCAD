#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
suite=${1:-all}
output=${2:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-shared-wave-output.XXXXXX")}
revision=$(cat Fixtures/SharedWaveBenchmark/core-revision.txt)
mkdir -p "$output"
python3 Scripts/test-tilted-pulse-pair.py
scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-shared-wave-build.XXXXXX")
task_completed=0
trap 'task_status=$?; rm -rf "$scratch"; if test "$task_completed" != 1 && test "$task_status" = 0; then exit 1; fi; exit "$task_status"' EXIT
source=${CONTINUUMKIT_BENCHMARK_SOURCE:-https://github.com/emmettl/ContinuumKit.git}
git clone --quiet "$source" "$scratch/ContinuumKit"
git -C "$scratch/ContinuumKit" checkout --quiet "$revision"
export CONTINUUMKIT_BENCHMARK_SOURCE="$scratch/ContinuumKit"
if test "$suite" = all; then suites='masked cylinder admittance absorbing-cylinder tilted-pulse'; else suites="$suite"; fi
for selected in $suites; do
 case "$selected" in
  masked) target=MaskedAdapter;; cylinder) target=CylinderAdapter;; admittance) target=AdmittanceAdapter;;
  absorbing-cylinder) target=AbsorbingCylinderAdapter;; tilted-pulse) target=TiltedPulseAdapter;;
  *) echo 'Unsupported shared suite' >&2;exit 1;;
 esac
 bash "Scripts/check-$selected.sh" "$output/original/$selected"
 consumer="$scratch/$selected"
 python3 Scripts/prepare-shared-wave-reference.py --root "$root" --core "$scratch/ContinuumKit" --suite "$selected" --output "$consumer"
 representations=plan
 if test "$selected" = tilted-pulse; then representations='plan mesh'; fi
 for representation in $representations; do
  for backend in cpu metal; do
   directory="$output/shared/$selected/$backend"
   if test "$representation" = mesh; then directory="$output/shared/$selected/mesh/$backend"; fi
   mkdir -p "$directory"
   python3 "$scratch/ContinuumKit/Scripts/benchmark-metadata.py" --root "$root" --repository https://github.com/emmettl/RoomCAD \
    --precision Float32 --dependency "continuumkit=$revision" --output "$directory/environment.json" Sources/AcousticCore/*.swift \
    Scripts/prepare-shared-wave-reference.py Scripts/check-shared-waves.sh Fixtures/SharedWaveBenchmark/Facades.swift
   arguments=(--backend "$backend" --output "$directory" --metadata "$directory/environment.json")
   if test "$selected" = tilted-pulse; then arguments+=(--representation "$representation"); fi
   swift run --package-path "$consumer" -c release -Xswiftc -enable-testing -Xswiftc -warnings-as-errors "$target" \
    "${arguments[@]}"
   python3 "$scratch/ContinuumKit/Scripts/verify-$selected-output.py" "$directory"
   cp "$consumer/Package.resolved" "$directory/consumer-Package.resolved"
   cp "$consumer/shared-reference-provenance.json" "$directory/reference-provenance.json"
  done
 done
 if test "$selected" = tilted-pulse; then python3 Scripts/verify-tilted-pulse-pair.py "$output/shared/$selected" --model-prefix RoomCAD.shared; fi
done

python3 Scripts/verify-shared-wave-pair.py "$output/original" "$output/shared" --output "$output/shared-comparison.json" --suites $suites
task_completed=1
