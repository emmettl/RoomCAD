#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
python3 Scripts/verify-original-wave-reference.py --require-git
output=${1:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-thin-probes-output.XXXXXX")}
mkdir -p "$output"
test -z "$(git status --porcelain)"
revision=$(git rev-parse HEAD)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-thin-probes-build.XXXXXX")
task_completed=0
trap 'task_status=$?; rm -rf "$scratch"; if test "$task_completed" != 1 && test "$task_status" = 0; then exit 1; fi; exit "$task_status"' EXIT
git clone --no-local --quiet "$root" "$scratch/RoomCAD"
test "$(git -C "$scratch/RoomCAD" rev-parse HEAD)" = "$revision"
export ROOMCAD_PRODUCTION_REVISION="$revision"
python3 - "$root" "$output" <<'PY'
import json,hashlib,subprocess,sys,platform
from pathlib import Path
root,output=map(Path,sys.argv[1:])
def run(*args):return subprocess.check_output(args,cwd=root,text=True).strip()
paths=[root/'Tests/AcousticCoreTests/OriginalMetalWaveSolver.swift',root/'Fixtures/OriginalWaveReference/metal-source.json',root/'Fixtures/OriginalWaveReference/MetalWaveSolver.swift.gz',root/'Scripts/original_wave_reference.py',root/'Tests/AcousticCoreTests/OriginalMaskedCPU.swift',root/'Fixtures/OriginalWaveReference/masked-cpu-source.json',root/'Fixtures/OriginalWaveReference/WaveSolver.swift.gz',root/'Scripts/original_wave_reference.py',root/'Scripts/verify-original-wave-reference.py',*root.glob('Sources/AcousticCore/*.swift'),*root.glob('Fixtures/ThinProbeBenchmark/**/*.swift'),root/'Scripts/check-thin-probes.sh',root/'Scripts/verify-thin-probe-output.py']
(output/'environment.json').write_text(json.dumps({'schemaVersion':1,'revision':run('git','rev-parse','HEAD'),'workingTreeDirty':bool(run('git','status','--porcelain')),'hardware':run('sysctl','-n','machdep.cpu.brand_string'),'swift':run('swift','--version'),'os':platform.platform(),'sourceHashes':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}},indent=2,sort_keys=True)+'\n')
PY
swift run --package-path "$scratch/RoomCAD/Fixtures/ThinProbeBenchmark" -c release -Xswiftc -enable-testing -Xswiftc -warnings-as-errors ThinProbeAdapter --output "$output"
cp "$scratch/RoomCAD/Fixtures/ThinProbeBenchmark/Package.resolved" "$output/consumer-Package.resolved"
python3 Scripts/verify-thin-probe-output.py "$output"
python3 Scripts/test-thin-probe-gate.py "$output"
task_completed=1
