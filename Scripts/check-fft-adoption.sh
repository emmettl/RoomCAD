#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
# The original alpha17 migration gate requires byte-identical callers and pins.
# Later intentional fitting changes have a separate current-application gate.
# Replay the accepted alpha17 producer rather than weakening its old assertions.
if ! python3 - "$root" <<'IS_ALPHA17'
import json,sys
from pathlib import Path
pins=json.loads((Path(sys.argv[1])/'Package.resolved').read_text())['pins']
raise SystemExit(0 if pins[0]['state']=={'version':'0.1.0-alpha.17','revision':'e94d329c55495ca561306174d624eadf5c8e7da0'} else 1)
IS_ALPHA17
then
    historical=6c176e6d6dc40faaa1da49cdb1804c3f4bfbe305
    historical_scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-frozen-fft-gate.XXXXXX")
    trap 'rm -rf "$historical_scratch"' EXIT
    git clone --no-local --quiet "$root" "$historical_scratch/RoomCAD"
    git -C "$historical_scratch/RoomCAD" checkout --quiet "$historical"
    historical_output=${1:-${ROOMCAD_FFT_ADOPTION_OUTPUT:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-frozen-fft-output.XXXXXX")}}
    bash "$historical_scratch/RoomCAD/Scripts/check-fft-adoption.sh" "$historical_output"
    python3 - "$root" "$historical_output" "$historical" <<'BINDING'
import json,subprocess,sys
from pathlib import Path
r,o=map(Path,sys.argv[1:3]);h=sys.argv[3]
d={'scope':'historical alpha17 FFT adoption; current fitting has a separate accuracy gate','currentProducer':subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),'protectedFFTProducer':h}
(o/'historical-binding.json').write_text(json.dumps(d,indent=2,sort_keys=True)+'\n')
BINDING
    exit 0
fi
test -z "$(git status --porcelain)"
revision=$(git rev-parse HEAD)
baseline=2bc11ed6a033e8642de4018e8e9ae9cfb4e1151c
output=${1:-${ROOMCAD_FFT_ADOPTION_OUTPUT:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-fft-adoption-output.XXXXXX")}}
mkdir -p "$output"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-fft-adoption-build.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
python3 Scripts/verify-fft-adoption-source.py
for mode in original shared; do
    git clone --no-local --quiet "$root" "$scratch/$mode"
    git -C "$scratch/$mode" checkout --quiet "$revision"
    if test "$mode" = original; then
        git -C "$scratch/$mode" checkout --quiet "$baseline"
        test -z "$(git -C "$scratch/$mode" status --porcelain)"
        git archive "$revision" Fixtures/FFTAdoptionBenchmark | tar -x -C "$scratch/$mode"
    fi
    mkdir -p "$output/$mode"
    export ROOMCAD_FFT_OUTPUT="$output/$mode"
    swift run --package-path "$scratch/$mode/Fixtures/FFTAdoptionBenchmark" -c release \
        -Xswiftc -enable-testing -Xswiftc -warnings-as-errors FFTAdoptionBenchmark
    cp "$scratch/$mode/Fixtures/FFTAdoptionBenchmark/Package.resolved" "$output/$mode/consumer-Package.resolved"
done
python3 - "$root" "$output" "$revision" <<'PYMETA'
import hashlib,json,platform,subprocess,sys
from pathlib import Path
r,o=map(Path,sys.argv[1:3]);revision=sys.argv[3]
def git(*args):return subprocess.check_output(['git',*args],cwd=r,text=True).strip()
paths=git('ls-tree','-r','--name-only',revision,'--','Package.swift','Package.resolved','Sources/AcousticCore','Sources/Audition','Fixtures/FFTAdoptionBenchmark','Scripts/check-fft-adoption.sh','Scripts/verify-fft-adoption-source.py','Scripts/verify-fft-adoption-output.py','Scripts/test-fft-adoption-gate.py').splitlines()
env={'schemaVersion':1,'candidate':revision,'baseline':'2bc11ed6a033e8642de4018e8e9ae9cfb4e1151c','workingTreeDirty':bool(git('status','--porcelain')),'comparisonSetup':'same committed fixture copied into clean protected baseline before compilation; original production sources and alpha12 pins untouched','sourceHashes':{p:hashlib.sha256(subprocess.check_output(['git','show',f'{revision}:{p}'],cwd=r)).hexdigest() for p in paths},'hardware':subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),'swift':subprocess.check_output(['swift','--version'],text=True).strip(),'os':platform.platform(),'nativeFormat':'complete little-endian IEEE754 binary; each JSON vector declares offset/count/width/hash'}
(o/'environment.json').write_text(json.dumps(env,indent=2,sort_keys=True)+'\n')
PYMETA
python3 Scripts/verify-fft-adoption-output.py "$output"
python3 Scripts/test-fft-adoption-gate.py "$output"
