#!/usr/bin/env python3
"""Require exact complete original/shared wave histories, geometry, errors and frozen reference identities."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('original',type=Path);p.add_argument('shared',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
load=lambda path:json.loads(path.read_text())
rows=[]
for results in sorted(a.shared.rglob('results.json')):
 relative=results.parent.relative_to(a.shared)
 source=a.original/relative
 candidate=load(results);baseline=load(source/'results.json')
 assert len(candidate)==len(baseline)>0,relative
 env=load(results.parent/'environment.json');oldenv=load(source/'environment.json')
 assert env['workingTreeDirty'] is False and oldenv['workingTreeDirty'] is False
 assert env['sourceHashes'] and all(env['sourceHashes'].get(path)==value for path,value in oldenv['sourceHashes'].items() if path.startswith('Sources/AcousticCore/')),relative
 provenance=load(results.parent/'reference-provenance.json')
 assert provenance['originalReferenceRevision']==oldenv['dependencies']['continuumkit'],relative
 assert provenance['referenceSourceHashes'] and provenance['sharedImplementationRevision']==env['dependencies']['continuumkit'],relative
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
assert rows
report={'schemaVersion':1,'status':'passed','scope':'all complete original/shared fields, clocks, layouts, wall traces, work and errors; unchanged original reference source','records':len(rows),'results':rows}
a.output.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
print('PASS exact complete original/shared histories and errors:',len(rows),'records; source geometry and original references retained')
