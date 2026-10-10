#!/usr/bin/env python3
"""Coherent corruption controls over complete actual application histories."""
import copy,hashlib,importlib.util,json,struct,sys
from pathlib import Path
sys.dont_write_bytecode=True
spec=importlib.util.spec_from_file_location('gate',Path(__file__).with_name('verify-affine-adoption-output.py'));g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
r=Path(sys.argv[1]);records={};raws={}
for mode in ['original','shared']:
 records[mode]=json.loads((r/mode/'application.json').read_text());raws[mode]=(r/mode/'native.bin').read_bytes()
# Populate immutable mathematical reference caches once. Every mutated scalar,
# input hash, prediction hash and policy decision is still checked afresh.
for mode in ['original','shared']:g.Policy(records[mode],raws[mode],mode).run()
def scalar(value):return {'value':str(value),'bits':format(int.from_bytes(struct.pack('<d',value),'little'),'x')}
def row(d,kind):return next(x for x in d['events'] if x['kind']==kind)
def case(d,family):return next(x for x in d['cases'] if x['family']==family)
def vector_change(meta,data,value):
 result=bytearray(data);width=meta['width'];start=meta['offset'];struct.pack_into('<d' if width==64 else '<f',result,start,value);end=start+meta['count']*(width//8);meta['sha256']=hashlib.sha256(memoryview(result)[start:end]).hexdigest();return bytes(result)
controls=['missing case','duplicate case','missing event','selected window','coherent slope','coherent anchor','coherent prediction bytes','coherent curve bytes','crossing coordinate','crossing index','noise floor','tail level','tail ledger','room parameter','calibration target','best factors coherent bytes','step factors coherent bytes','response identity','summary coherent spectrum bytes','native truncation','conditioning diagnostic']
for name in controls:
 for mode in ['original','shared']:
  if name in ['coherent anchor','conditioning diagnostic'] and mode=='original':continue
  d=copy.deepcopy(records[mode]);data=raws[mode]
  if name=='missing case':d['cases'].pop()
  elif name=='duplicate case':d['cases'].append(d['cases'][0])
  elif name=='missing event':d['events'].pop(12)
  elif name=='selected window':row(d,'room-window')['first']+=1
  elif name=='coherent slope':row(d,'index-fit')['slope']=scalar(1.0)
  elif name=='coherent anchor':row(d,'index-fit')['valueAtOrigin']=scalar(1.0)
  elif name=='coherent prediction bytes':data=vector_change(row(d,'index-fit')['diagnosticPredictions'],data,1.0)
  elif name=='coherent curve bytes':data=vector_change(row(d,'room-curve')['curve'],data,1.0)
  elif name=='crossing coordinate':row(d,'noise-crossing')['coordinate']=scalar(1.0)
  elif name=='crossing index':row(d,'noise-crossing')['cut']+=1
  elif name=='noise floor':row(d,'noise-iteration')['nextFloor']=scalar(-20.0)
  elif name=='tail level':row(d,'noise-tail')['level']=scalar(-1.0)
  elif name=='tail ledger':row(d,'noise-tail')['tail']=scalar(1.0)
  elif name=='room parameter':d['cases'][0]['roomParameters']['t30']=scalar(3.0)
  elif name=='calibration target':case(d,'calibration')['target'][2]=scalar(3.0)
  elif name=='best factors coherent bytes':data=vector_change(case(d,'calibration')['best']['factors'],data,2.0)
  elif name=='step factors coherent bytes':data=vector_change(case(d,'calibration')['steps'][1]['factors'],data,2.0)
  elif name=='response identity':case(d,'wave')['metadata']['channels'][0]['sourceID']='changed'
  elif name=='summary coherent spectrum bytes':data=vector_change(case(d,'wave')['summary']['channels'][0]['spectrum'],data,20.0)
  elif name=='native truncation':data=data[:-1]
  elif name=='conditioning diagnostic':row(d,'index-fit')['normalizedVariance']=scalar(3.0)
  try:g.Policy(d,data,mode).run()
  except (ValueError,KeyError,TypeError,IndexError):pass
  else:raise SystemExit('FAIL accepted coherent corruption '+mode+' '+name)
  print('REJECT',mode,name,flush=True)
# Pin and immutable source controls are tested without recompiling or relabelling
# captured producers. Only metadata is changed in a temporary view of the evidence.
import tempfile,shutil
for name in ['public pin','source producer','immutable source hash','trace binding']:
 with tempfile.TemporaryDirectory() as tmp:
  v=Path(tmp);(v/'shared').mkdir();base=r/'shared'
  for p in base.iterdir():(v/'shared'/p.name).symlink_to(p)
  env=json.loads((r/'environment.json').read_text())
  if name=='public pin':
   pin=json.loads((base/'consumer-Package.resolved').read_text());pin['pins'][0]['state']['revision']='0'*40
   file=v/'shared/consumer-Package.resolved';file.unlink();file.write_text(json.dumps(pin))
   try:g.dependency(v,'shared')
   except ValueError:pass
   else:raise SystemExit('FAIL accepted source pin')
  else:
   if name=='source producer':env['candidate']='0'*40
   elif name=='immutable source hash':env['sourceHashes']['Sources/AcousticCore/RoomParameters.swift']='0'*64
   else:
    p=v/'shared/source-bindings.json';p.unlink();d=json.loads((base/'source-bindings.json').read_text());d['traceSHA256']='0'*64;p.write_text(json.dumps(d))
   try:g.source_bindings(v,'shared',env,Path(__file__).resolve().parent.parent)
   except (ValueError,KeyError,TypeError):pass
   else:raise SystemExit('FAIL accepted '+name)
  print('REJECT',name,flush=True)
print('PASS 25 categories of completeness, source/pin, coherent native/scalar, selection, noise/tail, calibration and response-summary corruption controls')
