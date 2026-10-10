#!/usr/bin/env python3
"""Adversarial controls against complete app output evidence; never mutate baseline reports."""
import argparse, importlib.util, json, shutil, struct, tempfile
from pathlib import Path

spec = importlib.util.spec_from_file_location('production_verifier', Path(__file__).with_name('verify-wave-production-output.py'))
verifier = importlib.util.module_from_spec(spec); spec.loader.exec_module(verifier)

def change_json(root, filename, edit):
    p = root / filename; data = json.loads(p.read_text()); edit(data); p.write_text(json.dumps(data))

def corrupt_sample(data):
    run = data['cases'][0]['runs'][-1]
    run['shared'][0][-1] += 0.0001
    run['sharedBits'][0][-1] = int.from_bytes(struct.pack('>d', run['shared'][0][-1]), 'big')

def short_channel(data):
    run = data['cases'][0]['runs'][-1]
    run['shared'][0].pop(); run['sharedBits'][0].pop()

def main(root):
    verifier.verify(root)
    controls = [
        ('missing case', 'cpu-production.json', lambda d: d['cases'].pop()),
        ('missing terminal history', 'cpu-production.json', lambda d: d['cases'][0]['runs'].pop()),
        ('short channel and matching bits', 'cpu-production.json', short_channel),
        ('corrupted value and matching bits', 'cpu-production.json', corrupt_sample),
        ('wrong pressure clock', 'cpu-production.json', lambda d: d['cases'][0].update(timeStep=d['cases'][0]['timeStep'] * 2)),
        ('wrong dependency version', 'consumer-Package.resolved', lambda d: d['pins'][0]['state'].update(version='0.1.0-alpha.7')),
        ('missing faces', 'cpu-production.json', lambda d: d['cases'][0]['faces'].pop()),
        ('no generator wave runs', 'generator.json', lambda d: d['originalDiagnostics'].update(waveRuns=0)),
        ('changed saved metadata', 'shared-metadata.json', lambda d: d.update(generator='changed generator')),
    ]
    with tempfile.TemporaryDirectory(prefix='roomcad-production-controls-') as tmp:
        for i, (label, filename, edit) in enumerate(controls):
            copy = Path(tmp) / str(i); shutil.copytree(root, copy)
            change_json(copy, filename, edit)
            try: verifier.verify(copy)
            except (ValueError, KeyError, FileNotFoundError): pass
            else: raise AssertionError('Incomplete or corrupted evidence accepted: ' + label)
    print('PASS', 1 + len(controls), 'production report gate controls, including', len(controls), 'negative cases')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('root', type=Path)
    main(parser.parse_args().root)
