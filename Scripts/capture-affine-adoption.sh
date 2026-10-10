#!/bin/bash
# Capture complete committed current/original application evidence. The fit-only
# audit is independent; full window/noise/tail/calibration acceptance remains separate.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
test -z "$(git status --porcelain)"
revision=$(git rev-parse HEAD)
output=${1:-$(mktemp -d "${TMPDIR:-/tmp}/roomcad-affine-capture-output.XXXXXX")}
mkdir -p "$output"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/roomcad-affine-capture-build.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
git clone --no-local --quiet "$root" "$scratch/RoomCAD"
test "$(git -C "$scratch/RoomCAD" rev-parse HEAD)" = "$revision"
python3 - "$root" "$output" <<'META'
import hashlib,json,platform,subprocess,sys
from pathlib import Path
r,o=map(Path,sys.argv[1:])
def git(*args):return subprocess.check_output(['git',*args],cwd=r,text=True).strip()
paths=git('ls-files','Sources/AcousticCore','Sources/RoomDocument','Package.swift','Package.resolved','Fixtures/AffineAdoptionBenchmark','Fixtures/OriginalFittingReference','Scripts/original_fitting_reference.py','Scripts/prepare-affine-adoption.py','Scripts/capture-affine-adoption.sh','Scripts/audit-affine-adoption-fits.py').splitlines()
d={'schemaVersion':1,'candidate':git('rev-parse','HEAD'),'workingTreeDirty':bool(git('status','--porcelain')),'sourceHashes':{p:hashlib.sha256((r/p).read_bytes()).hexdigest() for p in paths},'hardware':subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),'swift':subprocess.check_output(['swift','--version'],text=True).strip(),'os':platform.platform(),'scope':'complete actual current/original traces and fit-only exact-native audit; full application adoption acceptance pending','execution':'serial fixture calls; explicit actual CPU and Metal generated wave cases; no trace hooks in production'}
(o/'environment.json').write_text(json.dumps(d,indent=2,sort_keys=True)+'\n')
META
for mode in original shared; do
    consumer="$scratch/$mode"
    python3 "$scratch/RoomCAD/Scripts/prepare-affine-adoption.py" --root "$scratch/RoomCAD" --mode "$mode" --output "$consumer"
    mkdir -p "$output/$mode"
    ROOMCAD_AFFINE_OUTPUT="$output/$mode" swift run --package-path "$consumer" -c release \
        -Xswiftc -enable-testing -Xswiftc -warnings-as-errors AffineAdoptionBenchmark
    cp "$consumer/Package.resolved" "$output/$mode/consumer-Package.resolved"
    cp "$consumer/source-bindings.json" "$output/$mode/source-bindings.json"
    cp "$consumer/Package.swift" "$output/$mode/compiled-Package.swift"
    cp -R "$consumer/Sources" "$output/$mode/compiled-Sources"
    python3 "$scratch/RoomCAD/Scripts/audit-affine-adoption-fits.py" "$output/$mode" --mode "$mode"
done
printf 'Captured complete committed application traces; full policy/corruption/two-host acceptance is still required.\n'
