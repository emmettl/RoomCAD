#!/usr/bin/env python3
"""Positive completeness and adversarial minimal-probe report controls."""
import argparse, importlib.util, json, shutil, struct, tempfile
from pathlib import Path
spec=importlib.util.spec_from_file_location('verifier',Path(__file__).with_name('verify-thin-probe-output.py'))
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
def edit(root,file,change):
    p=root/file;data=json.loads(p.read_text());change(data);p.write_text(json.dumps(data))
def corrupt(data):
    run=data['scenes'][0]['runs'][-1];run['shared'][0][-1]+=0.001
    run['sharedBits'][0][-1]=int.from_bytes(struct.pack('>d',run['shared'][0][-1]),'big')
def corrupt_metal(data):
    run=data['scenes'][0]['runs'][-1];run['sharedMetal'][0][-1]+=0.001
    run['sharedMetalBits'][0][-1]=int.from_bytes(struct.pack('>d',run['sharedMetal'][0][-1]),'big')
def main(root):
    v.verify(root)
    controls=[
        ('thin-probes.json',corrupt_metal),
        ('thin-probes.json',lambda d:d['scenes'][0]['runs'][0].pop('sharedMetal')),
        ('thin-probes.json',lambda d:d['scenes'].pop()),
        ('thin-probes.json',lambda d:d['scenes'][0]['runs'].pop()),
        ('thin-probes.json',lambda d:d['scenes'][0].update(probeCell=[0,1,1])),
        ('thin-probes.json',lambda d:d['scenes'][0]['velocityCells'].__setitem__(0,0)),
        ('thin-probes.json',corrupt),
        ('thin-probes.json',lambda d:next(r for r in d['scenes'][0]['runs'] if r['steps']==2)['metal'][0].__setitem__(1,1)),
        ('consumer-Package.resolved',lambda d:d['pins'][0]['state'].update(version='0.1.0-alpha.8')),
    ]
    with tempfile.TemporaryDirectory(prefix='thin-probe-controls-') as tmp:
        for i,(file,change) in enumerate(controls):
            copy=Path(tmp)/str(i);shutil.copytree(root,copy);edit(copy,file,change)
            try:v.verify(copy)
            except (ValueError,KeyError,FileNotFoundError):pass
            else:raise AssertionError('altered/incomplete thin evidence accepted '+str(i))
    print('PASS',1+len(controls),'thin-probe report controls, including',len(controls),'negative cases')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('root',type=Path);main(p.parse_args().root)
