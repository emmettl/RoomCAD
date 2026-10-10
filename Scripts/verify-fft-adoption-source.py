#!/usr/bin/env python3
import hashlib,json,subprocess
from pathlib import Path
r=Path(__file__).resolve().parent.parent
base='2bc11ed6a033e8642de4018e8e9ae9cfb4e1151c'
def git(*args):return subprocess.check_output(['git',*args],cwd=r)
raw=git('show',f'{base}:Sources/AcousticCore/RealFFT.swift')
assert hashlib.sha256(raw).hexdigest()=='63da5cb9c3ead610051a2b43faf3c345d4168d7e6580abd25ea202c18877b617'
for p in git('ls-files','Sources/AcousticCore','Sources/Audition').decode().splitlines():
 if p=='Sources/AcousticCore/RealFFT.swift':continue
 assert (r/p).read_bytes()==git('show',f'{base}:{p}'),f'unexpected caller/policy change: {p}'
pins=json.loads((r/'Package.resolved').read_text())['pins'];assert len(pins)==1 and pins[0]['state']=={'version':'0.1.0-alpha.17','revision':'e94d329c55495ca561306174d624eadf5c8e7da0'}
s=(r/'Sources/AcousticCore/RealFFT.swift').read_text();assert 'vDSP_' not in s and 'SpectralTransforms.RealFFT' in s and 'SpectralTransforms.Convolution.convolve' in s
print('PASS protected original FFT, unchanged application callers/policy and exact alpha17 delegation')
