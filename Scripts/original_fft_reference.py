"""Protected pre-alpha17 FFT compile dependency for verification-only consumers."""
import gzip,hashlib,json,subprocess
from pathlib import Path
REVISION='2bc11ed6a033e8642de4018e8e9ae9cfb4e1151c'
SHA='63da5cb9c3ead610051a2b43faf3c345d4168d7e6580abd25ea202c18877b617'
BLOB='6764b9fe1caafde501e30dac3bd94d74b88dfe39'
def original_fft_source(root:Path,require_git:bool=False)->bytes:
 m=json.loads((root/'Fixtures/OriginalFFTReference/source.json').read_text())
 if m['schemaVersion']!=1 or m['revision']!=REVISION or m['originalPath']!='Sources/AcousticCore/RealFFT.swift' or m['originalSHA256']!=SHA or m['originalGitBlob']!=BLOB or m['snapshotPath']!='Fixtures/OriginalFFTReference/RealFFT.swift.gz':raise ValueError('Original FFT identity changed')
 packed=(root/m['snapshotPath']).read_bytes()
 if hashlib.sha256(packed).hexdigest()!=m['snapshotSHA256']:raise ValueError('Original FFT compressed payload changed')
 raw=gzip.decompress(packed)
 if len(raw)!=m['originalBytes'] or hashlib.sha256(raw).hexdigest()!=SHA or hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()!=BLOB:raise ValueError('Original FFT source bytes changed')
 g=subprocess.run(['git','show',REVISION+':'+m['originalPath']],cwd=root,capture_output=True)
 if g.returncode==0 and g.stdout!=raw:raise ValueError('Original FFT differs from immutable Git source')
 if require_git and g.returncode!=0:raise ValueError('Original FFT Git source unavailable')
 return raw

def copy_original_fft_reference(root:Path,destination:Path)->None:
 if destination.resolve().is_relative_to((root/'Sources').resolve()):raise ValueError('Verification FFT must never be copied into production source')
 raw=original_fft_source(root)
 destination.mkdir(parents=True,exist_ok=True)
 (destination/'RealFFT.swift').write_bytes(raw)
