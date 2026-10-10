"""Protected pre-alpha18 fitting compile dependencies for frozen verification modules."""
import gzip,hashlib,json,subprocess
from pathlib import Path
REVISION='bf869284f29b7604a08d98cf66cf8a2c5619e525'
EXPECTED={'DecayAnalysis.swift': ('931363a156f4b52d6c390385ba5cce3f733f9a9742281ffc2063e50f575922b1', '63fc6c90bb524f50b1b18adddcdd55496d6581c0'), 'RoomParameters.swift': ('ad897708b1e654796786cc7745a68ed88817343df3589f66ff011bc57c6996da', '3b5c0e8761ee54b63e0a19b51596673bd702a780')}

def original_fitting_sources(root:Path,require_git:bool=False)->dict[str,bytes]:
 m=json.loads((root/'Fixtures/OriginalFittingReference/source.json').read_text())
 if m['schemaVersion']!=1 or m['revision']!=REVISION or set(m['files'])!=set(EXPECTED):raise ValueError('Original fitting identity changed')
 result={}
 for name,(sha,blob) in EXPECTED.items():
  d=m['files'][name]
  if d['originalPath']!='Sources/AcousticCore/'+name or d['snapshotPath']!='Fixtures/OriginalFittingReference/'+name+'.gz' or d['originalSHA256']!=sha or d['originalGitBlob']!=blob:raise ValueError('Original fitting source identity changed')
  packed=(root/d['snapshotPath']).read_bytes()
  if hashlib.sha256(packed).hexdigest()!=d['snapshotSHA256']:raise ValueError('Original fitting compressed payload changed')
  raw=gzip.decompress(packed)
  if len(raw)!=d['originalBytes'] or hashlib.sha256(raw).hexdigest()!=sha or hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()!=blob:raise ValueError('Original fitting source bytes changed')
  g=subprocess.run(['git','show',REVISION+':'+d['originalPath']],cwd=root,capture_output=True)
  if g.returncode==0 and g.stdout!=raw:raise ValueError('Original fitting differs from immutable Git source')
  if require_git and g.returncode!=0:raise ValueError('Original fitting Git source unavailable')
  result[name]=raw
 return result

def copy_original_fitting_reference(root:Path,destination:Path)->None:
 if destination.resolve().is_relative_to((root/'Sources').resolve()):raise ValueError('Verification fitting must never be copied into production source')
 raw=original_fitting_sources(root);destination.mkdir(parents=True,exist_ok=True)
 for name,data in raw.items():(destination/name).write_bytes(data)
