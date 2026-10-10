#!/usr/bin/env python3
"""Require original Git/snapshot/reference identity before running conformance."""
import argparse
import subprocess
from pathlib import Path
from original_wave_reference import original_masked_source

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
parser.add_argument('--require-git', action='store_true')
parser.add_argument('--product-binary', type=Path)
args = parser.parse_args()
original_masked_source(args.root, args.require_git)
print('PASS immutable original masked CPU snapshot, Git blob, verbatim method and canonical benchmark links')
if args.product_binary:
    symbols = subprocess.check_output(['nm', '-a', str(args.product_binary)])
    symbols = subprocess.check_output(['swift-demangle'], input=symbols).decode()
    if 'AcousticCore.SharedMaskedCPUSimulation' not in symbols or 'AcousticCore.SharedMetalSimulation' not in symbols:
        raise ValueError('Packaged application lacks the accepted shared backends')
    if 'simulateMasked(' in symbols or 'OriginalMaskedCPUSimulation' in symbols:
        raise ValueError('Verification-only original masked CPU code entered the application')
    print('PASS actual packaged application links shared backends and excludes the original masked CPU implementation')
