#!/usr/bin/env python3
import argparse
from pathlib import Path
from original_fft_reference import original_fft_source
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parent.parent);p.add_argument('--require-git',action='store_true');a=p.parse_args()
original_fft_source(a.root,a.require_git)
s=(a.root/'Sources/AcousticCore/RealFFT.swift').read_text()
assert 'import SpectralTransforms' in s and 'vDSP_' not in s,'production FFT must remain delegated to released Core'
print('PASS protected original FFT Git/blob/hash identity; production remains the shared alpha17 adapter')
