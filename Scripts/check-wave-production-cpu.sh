#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
python3 Scripts/verify-original-wave-reference.py --require-git
output=${1:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-wave-production-output.XXXXXX")}
mkdir -p "$output"
revision=$(git rev-parse HEAD)
test -z "$(git status --porcelain)"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-wave-production-build.XXXXXX")
task_completed=0
trap 'task_status=$?; rm -rf "$scratch"; if test "$task_completed" != 1 && test "$task_status" = 0; then exit 1; fi; exit "$task_status"' EXIT
git clone --no-local --quiet "$root" "$scratch/RoomCAD"
test "$(git -C "$scratch/RoomCAD" rev-parse HEAD)" = "$revision"
export ROOMCAD_PRODUCTION_REVISION="$revision"
python3 - "$root" "$output" <<'PY'
import hashlib,json,platform,subprocess,sys
from pathlib import Path
root,output=map(Path,sys.argv[1:])
def run(*args):return subprocess.check_output(args,cwd=root,text=True).strip()
paths=[root/'Tests/AcousticCoreTests/OriginalMetalWaveSolver.swift',root/'Fixtures/OriginalWaveReference/metal-source.json',root/'Fixtures/OriginalWaveReference/MetalWaveSolver.swift.gz',root/'Scripts/original_wave_reference.py',root/'Tests/AcousticCoreTests/OriginalMaskedCPU.swift',root/'Fixtures/OriginalWaveReference/masked-cpu-source.json',root/'Fixtures/OriginalWaveReference/WaveSolver.swift.gz',root/'Scripts/original_wave_reference.py',root/'Scripts/verify-original-wave-reference.py',Path('Package.swift'),Path('Package.resolved'),*sorted(root.glob('Sources/AcousticCore/*.swift')),*sorted(root.glob('Fixtures/WaveProductionBenchmark/**/*.swift')),Path('Scripts/check-wave-production-cpu.sh'),Path('Scripts/verify-wave-production-output.py'),Path('Scripts/test-wave-production-gate.py')]
hashes={str(p.relative_to(root) if p.is_absolute() else p):hashlib.sha256((p if p.is_absolute() else root/p).read_bytes()).hexdigest() for p in paths}
pins=json.loads((root/'Package.resolved').read_text())['pins'];pin=next(p for p in pins if p['identity']=='continuumkit')
env={'schemaVersion':1,'repository':'https://github.com/emmettl/RoomCAD','revision':run('git','rev-parse','HEAD'),'workingTreeDirty':bool(run('git','status','--porcelain')),'dependency':pin['state'],'hardware':run('sysctl','-n','machdep.cpu.brand_string'),'os':platform.platform(),'swift':run('swift','--version'),'sourceHashes':hashes,'scope':'current application masked CPU production adapter; complete outputs and independently labelled repeated timings'}
(output/'environment.json').write_text(json.dumps(env,indent=2,sort_keys=True)+'\n')
PY
swift run --package-path "$scratch/RoomCAD/Fixtures/WaveProductionBenchmark" -c release \
    -Xswiftc -enable-testing -Xswiftc -warnings-as-errors WaveProductionAdapter --output "$output"
cp "$scratch/RoomCAD/Fixtures/WaveProductionBenchmark/Package.resolved" "$output/consumer-Package.resolved"
python3 Scripts/verify-wave-production-output.py "$output"
python3 Scripts/test-wave-production-gate.py "$output"
task_completed=1
