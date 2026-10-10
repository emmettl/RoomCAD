#!/usr/bin/env python3
import argparse
from pathlib import Path
from original_fitting_reference import original_fitting_sources
p=argparse.ArgumentParser();p.add_argument('--require-git',action='store_true');a=p.parse_args();r=Path(__file__).resolve().parent.parent
original_fitting_sources(r,a.require_git)
print('PASS protected original fitting Git/blob/hash identities; production delegates to Numerics')
