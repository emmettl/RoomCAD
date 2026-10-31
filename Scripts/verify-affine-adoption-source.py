#!/usr/bin/env python3
"""Protect historical affine evidence and exact subsequent current-source adoptions."""
import hashlib,json,subprocess
from pathlib import Path
from original_fitting_reference import original_fitting_sources
from calibration_reporting_scope import verify_reporting_scope
from spatial_query_scope import ZONE, EXPECTED as SPATIAL_EXPECTED, CORE_QUERY, CORE_QUERY_SHA256, verify_spatial_query_scope, verify_spatial_query_files
from verified_calibration_scope import NEW_SOURCE, EXPECTED, verify_verified_calibration_scope
r=Path(__file__).resolve().parent.parent
# Preserve the accepted alpha23 gate verbatim in its committed source tree.
# The portable split has a separate token-exact current-source proof.
if (r/'Sources/AcousticModel').exists():
 import tempfile,sys
 from portable_source import verify,BASE
 verify(r)
 ck=r/'.build/checkouts/ContinuumKit'
 with tempfile.TemporaryDirectory(prefix='roomcad-historical-source-') as folder:
  legacy=Path(folder)/'RoomCAD'
  subprocess.run(['git','clone','--quiet','--shared',str(r),str(legacy)],check=True)
  subprocess.run(['git','checkout','--quiet',BASE],cwd=legacy,check=True)
  dependency=legacy/'.build/checkouts/ContinuumKit';dependency.parent.mkdir(parents=True)
  subprocess.run(['git','clone','--quiet','--shared',str(ck),str(dependency)],check=True)
  subprocess.run(['git','checkout','--quiet','b5a317486f1f87dd28ddeb9733587a41061d882c'],cwd=dependency,check=True)
  subprocess.run([sys.executable,str(legacy/'Scripts/verify-affine-adoption-source.py')],check=True)
 # Every existing acoustic operator remains byte-identical on the new tag.
 old='0e0929f4a0806940ed2fc5be5f81d1a82034cc8c'
 for product in ['ImpulseResponseKit','SpectralTransforms','LinearAcoustics','LinearAcousticsMetal','Numerics']:
  paths=subprocess.check_output(['git','ls-tree','-r','--name-only',old,'Sources/'+product],cwd=ck,text=True).splitlines()
  for path in paths:
   assert subprocess.check_output(['git','show',old+':'+path],cwd=ck)==(ck/path).read_bytes(),path
 print('PASS current portable split and unchanged active acoustic operators on exact alpha29')
 sys.exit(0)
base='bf869284f29b7604a08d98cf66cf8a2c5619e525'
old='e94d329c55495ca561306174d624eadf5c8e7da0';core='0e0929f4a0806940ed2fc5be5f81d1a82034cc8c'
def git(root,*args):return subprocess.check_output(['git',*args],cwd=root)
original_fitting_sources(r,True)
paths=set(git(r,'ls-tree','-r','--name-only',base,'Sources').decode().splitlines())
actual={str(p.relative_to(r)) for p in (r/'Sources').rglob('*') if p.is_file()}
spatial=(r/ZONE).read_bytes()!=git(r,'show',base+':'+ZONE)
if spatial:verify_spatial_query_files({p:(r/p).read_bytes() for p in SPATIAL_EXPECTED})
verified=NEW_SOURCE in actual
assert actual==paths|({NEW_SOURCE} if verified else set()),'production source tree changed outside declared files'
if verified:verify_verified_calibration_scope({p:(r/p).read_bytes() for p in EXPECTED})
allowed={'Sources/AcousticCore/RoomParameters.swift','Sources/AcousticCore/DecayAnalysis.swift'}
for path in paths-allowed:
 before=git(r,'show',base+':'+path);current=(r/path).read_bytes()
 if spatial and path==ZONE:verify_spatial_query_scope(before,current)
 elif verified and path in EXPECTED:pass # Exact candidate identities checked above.
 elif path=='Sources/RoomCAD/CalibrationSection.swift':verify_reporting_scope(before,current)
 else:assert current==before,path
pins=json.loads((r/'Package.resolved').read_text())['pins'];assert len(pins)==1
if spatial:
 from spatial_query_scope import CORE_VERSION, CORE_REVISION
 assert pins[0]['state']=={'version':CORE_VERSION,'revision':CORE_REVISION}
else:assert pins[0]['state']=={'version':'0.1.0-alpha.18','revision':core}
for path in allowed:
 s=(r/path).read_text();assert 'import Numerics' in s and 'AffineLeastSquares.fit' in s and 'sxx' not in s and 'sxy' not in s,path
room=(r/'Sources/AcousticCore/RoomParameters.swift').read_text();decay=(r/'Sources/AcousticCore/DecayAnalysis.swift').read_text()
assert 'values.indices.map { Double($0 + offset) }' in room
assert '(first...last).map { Double($0) / Double(sampleRate) }' in decay
assert 'fit.coordinate(at: floor)' in room and 'finalFit?.value(at: Double(crossing))' in room
assert 'Int(exactly:' in room or 'Int(\n                    exactly:' in room
ck=r/'.build/checkouts/ContinuumKit'
assert ck.exists(),'resolve the exact package before source verification'
if spatial:
 assert git(ck,'rev-parse','HEAD').decode().strip()==CORE_REVISION
 assert hashlib.sha256((ck/CORE_QUERY).read_bytes()).hexdigest()==CORE_QUERY_SHA256
 # Active acoustic operators are byte-identical to the accepted alpha18 release.
 # New Numerics operators, portable CAD imports and default-preserving zoom were
 # independently released later; they are not passed off as alpha18 capture evidence.
 stable=['DocumentKit','ImpulseResponseKit','SpectralTransforms','LinearAcoustics','LinearAcousticsMetal']
 for product in stable:
  files=git(ck,'ls-tree','-r','--name-only',core,'Sources/'+product).decode().splitlines()
  assert files==git(ck,'ls-tree','-r','--name-only',CORE_REVISION,'Sources/'+product).decode().splitlines(),product
  for path in files:assert git(ck,'show',core+':'+path)==(ck/path).read_bytes(),path
 for path in git(ck,'ls-tree','-r','--name-only',core,'Sources/Numerics').decode().splitlines():
  assert git(ck,'show',core+':'+path)==(ck/path).read_bytes(),path
products=['SceneModel','SceneView','SceneRender','GeometryImport','DocumentKit','ImpulseResponseKit','Thermodynamics','CompressibleFlow','BenchmarkSupport','LinearAcoustics','LinearAcousticsMetal','SpectralTransforms']
for product in products:
 paths=git(ck,'ls-tree','-r','--name-only',old,'Sources/'+product).decode().splitlines()
 assert paths==git(ck,'ls-tree','-r','--name-only',core,'Sources/'+product).decode().splitlines(),product
 for path in paths:assert git(ck,'show',old+':'+path)==git(ck,'show',core+':'+path),path
print('PASS historical alpha18 affine source gate and frozen prior-product identities')
if spatial:print('PASS exact released Double-query adoption, protected fitted-zone policy and unchanged active acoustic operators')
else:print('PASS exact alpha18 current pin')
