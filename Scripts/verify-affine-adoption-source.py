#!/usr/bin/env python3
"""Bound current affine adoption to two callers and byte-preserved prior Core products."""
import hashlib,json,subprocess
from pathlib import Path
from original_fitting_reference import original_fitting_sources
from calibration_reporting_scope import verify_reporting_scope
from verified_calibration_scope import NEW_SOURCE, EXPECTED, verify_verified_calibration_scope
r=Path(__file__).resolve().parent.parent
base='bf869284f29b7604a08d98cf66cf8a2c5619e525'
old='e94d329c55495ca561306174d624eadf5c8e7da0';core='0e0929f4a0806940ed2fc5be5f81d1a82034cc8c'
def git(root,*args):return subprocess.check_output(['git',*args],cwd=root)
original_fitting_sources(r,True)
paths=set(git(r,'ls-tree','-r','--name-only',base,'Sources').decode().splitlines())
actual={str(p.relative_to(r)) for p in (r/'Sources').rglob('*') if p.is_file()}
verified=NEW_SOURCE in actual
assert actual==paths|({NEW_SOURCE} if verified else set()),'production source tree changed outside declared files'
if verified:verify_verified_calibration_scope({p:(r/p).read_bytes() for p in EXPECTED})
allowed={'Sources/AcousticCore/RoomParameters.swift','Sources/AcousticCore/DecayAnalysis.swift'}
for path in paths-allowed:
 before=git(r,'show',base+':'+path);current=(r/path).read_bytes()
 if verified and path in EXPECTED:pass # Exact candidate identities checked above.
 elif path=='Sources/RoomCAD/CalibrationSection.swift':verify_reporting_scope(before,current)
 else:assert current==before,path
pins=json.loads((r/'Package.resolved').read_text())['pins'];assert len(pins)==1 and pins[0]['state']=={'version':'0.1.0-alpha.18','revision':core}
for path in allowed:
 s=(r/path).read_text();assert 'import Numerics' in s and 'AffineLeastSquares.fit' in s and 'sxx' not in s and 'sxy' not in s,path
room=(r/'Sources/AcousticCore/RoomParameters.swift').read_text();decay=(r/'Sources/AcousticCore/DecayAnalysis.swift').read_text()
assert 'values.indices.map { Double($0 + offset) }' in room
assert '(first...last).map { Double($0) / Double(sampleRate) }' in decay
assert 'fit.coordinate(at: floor)' in room and 'finalFit?.value(at: Double(crossing))' in room
assert 'Int(exactly:' in room or 'Int(\n                    exactly:' in room
ck=r/'.build/checkouts/ContinuumKit'
assert ck.exists(),'resolve the exact package before source verification'
products=['SceneModel','SceneView','SceneRender','GeometryImport','DocumentKit','ImpulseResponseKit','Thermodynamics','CompressibleFlow','BenchmarkSupport','LinearAcoustics','LinearAcousticsMetal','SpectralTransforms']
for product in products:
 paths=git(ck,'ls-tree','-r','--name-only',old,'Sources/'+product).decode().splitlines()
 assert paths==git(ck,'ls-tree','-r','--name-only',core,'Sources/'+product).decode().splitlines(),product
 for path in paths:assert git(ck,'show',old+':'+path)==git(ck,'show',core+':'+path),path
print('PASS bounded two-caller affine adoption, explicit coordinate units, exact alpha18 pin and byte-preserved prior Core products')
