#!/usr/bin/env python3
"""Bind shared steppers to original app geometry/observation code and frozen original Core references."""
import argparse,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
SUITES={'masked':('Masked','MaskedAdapter'),'cylinder':('Cylinder','CylinderAdapter'),'admittance':('Admittance','AdmittanceAdapter'),'absorbing-cylinder':('AbsorbingCylinder','AbsorbingCylinderAdapter'),'tilted-pulse':('TiltedPulse','TiltedPulseAdapter')}
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);p.add_argument('--core',type=Path,required=True);p.add_argument('--suite',choices=SUITES,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
name,target=SUITES[a.suite];fixture=a.root/'Fixtures'/(name+'Benchmark')
original=(fixture/'core-revision.txt').read_text().strip();shared=(a.root/'Fixtures/SharedWaveBenchmark/core-revision.txt').read_text().strip()
def git(revision,path):return subprocess.check_output(['git','show',revision+':'+path],cwd=a.core)
# Preserve every original oracle/guard byte in a separate module, even where later Core revisions added capabilities.
shutil.copytree(fixture,a.output,dirs_exist_ok=False)
subprocess.run([sys.executable,str(a.root/'Scripts'/('prepare-'+a.suite+'-reference.py')),'--root',str(a.root),'--output',str(a.output)],check=True)
ref=a.output/'Sources/FrozenBenchmarkSupport';ref.mkdir()
paths=subprocess.check_output(['git','ls-tree','-r','--name-only',original,'Sources/BenchmarkSupport'],cwd=a.core,text=True).splitlines()
hashes={}
for path in paths:
 data=git(original,path);destination=ref/Path(path).relative_to('Sources/BenchmarkSupport');destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(data);hashes[path]=hashlib.sha256(data).hexdigest()
# The original references import this pure law; assert its full source also remains byte-identical.
thermo=subprocess.check_output(['git','ls-tree','-r','--name-only',original,'Sources/Thermodynamics'],cwd=a.core,text=True).splitlines()
for path in thermo:
 if git(original,path)!=git(shared,path):raise ValueError('Original reference thermodynamics changed: '+path)
main=a.output/'Sources'/target/'Adapter.swift';text=main.read_text()
start=text.index('final class ');end=text.index('\n}\n',start)+3
# Only replace the original evolution class. Preserve every app-owned audit declaration before main.
main_start=text.index('@main ',end);retained_declarations=text[end:main_start]
gpu=re.search(r'final class (\w+)',text[start:end]).group(1)
text=text[:start]+'typealias '+gpu+' = SharedWaveGPU\n\n'+text[end:]
cpu_files=list((a.output/'Sources'/target).glob('Source*CPU.swift'))
if len(cpu_files)!=1:raise ValueError('Expected one original CPU binding')
cpu=re.search(r'final class (\w+)',cpu_files[0].read_text()).group(1)
cpu_files[0].write_text('typealias '+cpu+' = SharedWaveCPU\n')
text=text.replace('import BenchmarkSupport','import FrozenBenchmarkSupport')
text,count=re.subn(r'(?<!try )\b'+cpu+r'\(', 'try '+cpu+'(',text)
if count!=1:raise ValueError('Expected one CPU construction')
text=text.replace('cpu.advance(', 'try cpu.advance(').replace('cpu?.advance(', 'try cpu?.advance(')
text,count=re.subn(r'c\s*:\s*(\w+)\.speed',lambda m:m.group(0)+', density: '+m.group(1)+'.density',text)
if count!=2:raise ValueError('Expected CPU/GPU physical density bindings')
text=text.replace('RoomCAD.\\(backend).','RoomCAD.shared.\\(backend).')
if retained_declarations not in text:raise ValueError('App-owned audit declarations changed during binding')
main.write_text(text)
shutil.copyfile(a.root/'Fixtures/SharedWaveBenchmark/Facades.swift',a.output/'Sources'/target/'SharedWaveFacades.swift')
(a.output/'core-revision.txt').write_text(shared+'\n')
package=a.output/'Package.swift';text=package.read_text().replace('.executableTarget(','.target(name: "FrozenBenchmarkSupport", dependencies: [.product(name: "Thermodynamics", package: "continuumkit")]),\n        .executableTarget(',1).replace('.product(name: "BenchmarkSupport", package: "continuumkit")','"FrozenBenchmarkSupport", .product(name: "LinearAcoustics", package: "continuumkit"), .product(name: "LinearAcousticsMetal", package: "continuumkit")');package.write_text(text)
(a.output/'shared-reference-provenance.json').write_text(json.dumps({'schemaVersion':1,'suite':a.suite,'originalReferenceRevision':original,'sharedImplementationRevision':shared,'referenceSourceHashes':hashes,'thermodynamics':'original source byte-identical','observation':'snapshot copies into CPU/GPU observer mirrors; not a zero-copy or performance comparison'},indent=2,sort_keys=True)+'\n')
print('Prepared',a.suite,'shared steppers with original frozen references',original,'and implementation',shared)
