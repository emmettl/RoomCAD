#!/usr/bin/env python3
"""Split the reviewed application model; no numerical statements are rewritten.

The lexical reader is from BombCAD's MIT-licensed split tools. Package visibility
allows the application generator to use its model's existing implementation.
"""
from pathlib import Path
import json, hashlib, sys
from swift_source import parse
ROOT=Path(__file__).resolve().parents[2]
CORE=ROOT/'Sources/AcousticCore'; MODEL=ROOT/'Sources/AcousticModel'
KEEP={'AbsorptionCalibration.swift','BandRenderer.swift','DiffuseTail.swift','ValidationScene.swift',
      'ValidatedAbsorptionCalibration.swift','WaveAccuracy.swift','WaveGridLayout.swift','WaveSolver.swift',
      'SharedWaveSimulation.swift','SharedMetalSimulation.swift','RoomResponse.swift'}

def package_access(text):
    sf=parse(text); edits=[]
    for top in sf.decls:
        for decl in top.walk():
            if decl.access is not None or decl.kind in {'import','extension','case','operator','precedencegroup','deinit'}:continue
            # Private enclosing declarations stay private implementation details.
            parent=decl.parent
            while parent and parent.access not in {'private','fileprivate'}:parent=parent.parent
            if parent:continue
            token=sf.tokens[decl.header]
            edits.append((token.start,'package '))
    for offset,insert in sorted(set(edits),reverse=True):text=text[:offset]+insert+text[offset:]
    return text

def main():
    if MODEL.exists():raise SystemExit('AcousticModel already exists; use the recorded split map for verification.')
    MODEL.mkdir()
    mapping={}
    for path in sorted(CORE.glob('*.swift')):
        if path.name in KEEP:continue
        original=path.read_text();new=MODEL/path.name
        new.write_text(package_access(original));path.unlink()
        mapping[str(path.relative_to(ROOT))]=str(new.relative_to(ROOT))
    path=CORE/'RoomResponse.swift';text=path.read_text()
    generator=text.index('public enum RoomResponseGenerator {')
    progress=text.index('public enum GenerationQuality:')
    plan=text.index('/// The wave solver\'s crossover and grid')
    model=text[:generator]+text[progress:plan]
    (MODEL/'RoomResponseTypes.swift').write_text(package_access(model))
    path.write_text('import AcousticModel\n'+text[:text.index('/// A point in the room')]+text[generator:progress]+text[plan:])
    for path in CORE.glob('*.swift'):
        if path.name!='RoomResponse.swift':path.write_text('import AcousticModel\n'+path.read_text())
    (CORE/'Exports.swift').write_text('@_exported import AcousticModel\n')
    mapping['Sources/AcousticCore/RoomResponse.swift']=['Sources/AcousticModel/RoomResponseTypes.swift','Sources/AcousticCore/RoomResponse.swift']
    (ROOT/'Scripts/split/moves.json').write_text(json.dumps(mapping,indent=2)+'\n')
if __name__=='__main__':main()
