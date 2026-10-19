"""Bind the portable module split to the accepted application source.

Frozen consumers still compile one AcousticCore module. Before returning historical
bytes, prove that the current declarations have exactly the same Swift tokens,
allowing only the recorded imports, package access and assignment-only constructors.
No numerical token, string (including identifiers), or control flow is exempted.
"""
from pathlib import Path
import json, subprocess, sys
sys.path.insert(0, str(Path(__file__).parent/'split'))
from swift_source import parse, tokenize
BASE = '9d532557afd7e2853044957c28c2cb6a30d27ec0'
ROOT = Path(__file__).resolve().parents[1]
MOVES = json.loads((ROOT/'Scripts/split/moves.json').read_text())
MOVES['Tests/AcousticCoreTests/SharedBoxQueryTests.swift']='Tests/AcousticModelTests/SharedBoxQueryTests.swift'
INITS = json.loads((ROOT/'Scripts/split/initializers.json').read_text())

def git_source(root, path):
    return subprocess.check_output(['git','show',BASE+':'+path],cwd=root)

def tokens(text):
    return [t.text for t in tokenize(text)]

def without_package(text):
    sf=parse(text);positions=set()
    for top in sf.decls:
        for d in top.walk():
            positions.update(i for i in range(d.header,d.keyword) if sf.tokens[i].text=='package')
    return [t.text for i,t in enumerate(sf.tokens) if i not in positions]

def strip(text, path):
    sf = parse(text)
    spec = INITS.get(path)
    if spec:
        owner = next(d for d in sf.decls if d.name == spec['type'])
        init = next(d for d in owner.members if d.kind == 'init')
        assert [t.text for t in sf.tokens[init.header:init.end+1]] == spec['tokens'], 'split constructor changed: '+path
        text = text[:sf.tokens[init.header].start]+text[sf.tokens[init.end].end:]
    text = text.replace('import AcousticModel\n','').replace('import AuditionDSP\n','')
    return without_package(text)

def declarations(parts):
    # RoomResponse's types and generator changed file order, never declaration order inside a type.
    result=[]
    for text in parts:
        sf=parse(text)
        for d in sf.decls:
            if d.kind == 'import': continue
            result.append(tuple(without_package(text[sf.tokens[d.header].start:sf.tokens[d.end].end])))
    return sorted(result)

def source_before_split(root, path):
    """Validated original bytes for historical source guards and verification-only builds."""
    root=Path(root)
    if not (root/'Sources/AcousticModel').exists(): return (root/path).read_bytes()
    original=git_source(root,path)
    moved=MOVES.get(path,path)
    paths=moved if isinstance(moved,list) else [moved]
    parts=[]
    for p in paths:
        text=(root/p).read_text()
        # Validate and remove only the explicit constructors recorded at the split.
        if p in INITS:
            sf=parse(text);spec=INITS[p];owner=next(d for d in sf.decls if d.name==spec['type']);i=next(d for d in owner.members if d.kind=='init')
            assert [t.text for t in sf.tokens[i.header:i.end+1]]==spec['tokens'], 'split constructor changed: '+p
            text=text[:sf.tokens[i.header].start]+text[sf.tokens[i.end].end:]
        if path=='Tests/AcousticCoreTests/SharedBoxQueryTests.swift': text=text.replace('@testable import AcousticModel','@testable import AcousticCore')
        parts.append(text.replace('import AcousticModel\n','').replace('import AuditionDSP\n',''))
    expected=original.decode()
    if path.endswith('/WaveSolver.swift'):
        expected=expected.replace('    private var selectedMetalBackend:', '''    static var metalAvailable: Bool {
        #if canImport(Metal)
            SharedMetalSimulation.shared != nil
        #else
            false
        #endif
    }

    private var selectedMetalBackend:''')
        expected=expected.replace('            if usesSharedMetalDefault { return SharedMetalSimulation.shared }','''            #if canImport(Metal)
                if usesSharedMetalDefault { return SharedMetalSimulation.shared }
            #endif''')
    if len(paths)>1:
        assert declarations([expected])==declarations(parts), 'split declaration changed: '+path
    else:
        assert tokens(expected)==without_package(parts[0]), 'split source changed: '+path
    return original

def copy_monolithic_core(root, destination, exclude=()):
    """Reconstruct an equivalent macOS module for frozen, single-module manifests."""
    root=Path(root);destination=Path(destination)
    if destination.resolve().is_relative_to((root/'Sources').resolve()): raise ValueError('reference source must stay outside production')
    destination.mkdir(parents=True,exist_ok=True)
    paths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'Sources/AcousticCore'],cwd=root,text=True).splitlines()
    for path in paths:
        if Path(path).name not in exclude:
            (destination/Path(path).name).write_bytes(source_before_split(root,path))

def verify(root=ROOT):
    paths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'Sources/AcousticCore'],cwd=root,text=True).splitlines()
    for path in paths: source_before_split(root,path)
    pin=json.loads((root/'Package.resolved').read_text())['pins']
    assert len(pin)==1 and pin[0]['state']=={'version':'0.1.0-alpha.29','revision':'eae6589985e5ab8e096d595f352d36447e4573eb'}, 'portable dependency pin changed'
    model=set(p for path in paths for p in (MOVES[path] if isinstance(MOVES.get(path),list) else [MOVES.get(path,path)]))
    actual={str(p.relative_to(root)) for directory in ['AcousticModel','AcousticCore'] for p in (root/'Sources'/directory).glob('*.swift')}
    assert actual==model|{'Sources/AcousticModel/LinuxSIMD.swift','Sources/AcousticCore/Exports.swift'}, 'unexpected acoustic source file'
    assert (root/'Sources/AcousticCore/Exports.swift').read_text()=='@_exported import AcousticModel\n'
    assert (root/'Sources/Audition/Exports.swift').read_text()=='@_exported import AuditionDSP\n'
    for name in ['AuditionPreview.swift','WaveformOverview.swift']:
        old=git_source(root,'Sources/Audition/'+name).decode().replace('import AcousticCore\n','')
        current=(root/'Sources/AuditionDSP'/name).read_text().replace('import AcousticModel\n','')
        assert tokens(old)==tokens(current),'audition DSP changed: '+name
    original=git_source(root,'Sources/Audition/DryClip.swift').decode()
    pieces=[(root/'Sources'/module/'DryClip.swift').read_text() for module in ['AuditionDSP','Audition']]
    assert declarations([original])==declarations(pieces),'dry clip declarations changed'
    for name in ['RoomProject.swift','ResponseSummary.swift']:
        old=git_source(root,'Sources/RoomDocument/'+name).decode().replace('import AcousticCore','import AcousticModel')
        assert tokens(old)==tokens((root/'Sources/RoomDocument'/name).read_text()),'document schema changed: '+name
    return paths

if __name__=='__main__':
    verify();print('PASS portable split: every original acoustic declaration and numerical token preserved')
