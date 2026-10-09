#!/usr/bin/env python3
"""Require exact complete original/shared wave histories, geometry, errors and frozen reference identities."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('original',type=Path);p.add_argument('shared',type=Path);p.add_argument('--output',type=Path,required=True);p.add_argument('--suites',nargs='+',choices=['masked','cylinder','admittance','absorbing-cylinder','tilted-pulse'],required=True);p.add_argument('--core-revision');p.add_argument('--core-version');a=p.parse_args()
fixture=Path(__file__).resolve().parents[1]/'Fixtures/SharedWaveBenchmark'
revision=a.core_revision or (fixture/'core-revision.txt').read_text().strip()
version=a.core_version or (fixture/'core-version.txt').read_text().strip()
load=lambda path:json.loads(path.read_text())
rows=[]
counts={'masked':12,'cylinder':6,'admittance':12,'absorbing-cylinder':6,'tilted-pulse':6}
expected={Path(suite)/backend:counts[suite] for suite in a.suites for backend in ['cpu','metal']}
if 'tilted-pulse' in a.suites:
 expected.update({Path('tilted-pulse')/'mesh'/backend:6 for backend in ['cpu','metal']})
actual={path.parent.relative_to(a.shared) for path in a.shared.rglob('results.json')}
assert actual==set(expected),('Missing or unexpected complete suite/backend reports',sorted(map(str,set(expected)-actual)),sorted(map(str,actual-set(expected))))
for results in sorted(a.shared.rglob('results.json')):
 relative=results.parent.relative_to(a.shared)
 source=a.original/relative
 candidate=load(results);baseline=load(source/'results.json')
 assert len(candidate)==len(baseline)==expected[relative],relative
 env=load(results.parent/'environment.json');oldenv=load(source/'environment.json')
 assert env['workingTreeDirty'] is False and oldenv['workingTreeDirty'] is False
 assert env['sourceHashes'] and all(env['sourceHashes'].get(path)==value for path,value in oldenv['sourceHashes'].items() if path.startswith('Sources/AcousticCore/')),relative
 provenance=load(results.parent/'reference-provenance.json')
 assert provenance['originalReferenceRevision']==oldenv['dependencies']['continuumkit'],relative
 assert provenance['referenceSourceHashes'] and provenance['sharedImplementationRevision']==env['dependencies']['continuumkit']==revision,relative
 assert provenance['sharedImplementationVersion']==version,relative
 resolved=load(results.parent/'consumer-Package.resolved')
 pins=[pin for pin in resolved['pins'] if pin['identity']=='continuumkit']
 assert len(pins)==1 and pins[0]['state'].get('version')==version and pins[0]['state']['revision']==revision,(relative,'wrong resolved shared dependency')
 oldpins=[pin for pin in load(source/'consumer-Package.resolved')['pins'] if pin['identity']=='continuumkit']
 assert len(oldpins)==1 and oldpins[0]['state']['revision']==provenance['originalReferenceRevision'],(relative,'wrong resolved original reference')
 for i,(new,old) in enumerate(zip(candidate,baseline)):
  assert new['status']==old['status']=='supported'
  assert new['model'].replace('RoomCAD.shared.','RoomCAD.',1)==old['model']
  # Only producer identity, environment and elapsed cost differ; every numerical/schema key is exact.
  semantic=lambda r:{k:v for k,v in r.items() if k not in ['model','environment','runtime']}
  assert semantic(new)==semantic(old),(str(relative),i,'complete numerical/schema mismatch')
  rows.append({'directory':str(relative),'case':new['specification']['id'],'resolution':new['resolution'],'exactHistory':True,'exactErrors':True,'originalReference':provenance['originalReferenceRevision'],'sharedImplementation':provenance['sharedImplementationRevision']})
 geometry=results.parent/'geometry.json'
 if geometry.exists():assert load(geometry)==load(source/'geometry.json'),(relative,'geometry')
 checks=load(results.parent/'conformance.json')
 assert checks and all(row['status']=='passed' for row in checks),relative
assert len(rows)==sum(expected.values())
report={'schemaVersion':1,'status':'passed','scope':'all complete original/shared fields, clocks, layouts, wall traces, work and errors; unchanged original reference source','sharedImplementationVersion':version,'sharedImplementationRevision':revision,'records':len(rows),'results':rows}
a.output.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
print('PASS exact complete original/shared histories and errors:',len(rows),'records; source geometry and original references retained')
