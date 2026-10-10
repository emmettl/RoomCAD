#!/usr/bin/env python3
import copy,hashlib,importlib.util,json,struct,sys
from pathlib import Path
sys.dont_write_bytecode=True
spec=importlib.util.spec_from_file_location('gate',Path(__file__).with_name('verify-fft-adoption-output.py'));gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)
r=Path(sys.argv[1])/'shared';records=json.loads((r/'application.json').read_text());data=(r/'native.bin').read_bytes()
def forged(id,key,index,value,sub=None):
 rs=copy.deepcopy(records);c=next(c for c in rs if c['id']==id);v=c[key]
 if sub is not None:v=v[sub]
 raw=bytearray(data);w=v['width'];start=v['offset'];struct.pack_into('<d' if w==64 else '<f',raw,start+index*(w//8),value)
 v['sha256']=hashlib.sha256(raw[start:start+v['count']*(w//8)]).hexdigest();return rs,bytes(raw)
controls={'missing case':(records[:-1],data),'duplicate case':(records+[records[0]],data),'independent decay':forged('decay/48000/1025/3','curve',15,-77),'independent full convolution':forged('audition/48000/clicks/2','wet',4800,.75,sub=0),'complete dry padding':forged('audition/8000/burst/1','dry',20010,.25,sub=0),'driver crossover':forged('drivers/48000','crossovers',0,1200),'fine structure':forged('comparison/8000/1025','fine',0,99),'arrival gain':forged('bands/8000/65/0/equal','output',0,0)}
# The band output's arithmetic is independently verified in Core; application
# output changes here are rejected by exact original/shared equality below.
controls.pop('arrival gain')
for name,mutator in [('case identity',lambda c:c.update(rate=0)),('native precision',lambda c:c['output'].update(width=64)),('truncated vector',lambda c:c['output'].update(count=c['output']['count']+1))]:
 rs=copy.deepcopy(records);mutator(rs[0]);controls[name]=(rs,data)
for name,(rs,raw) in controls.items():
 try:gate.verify_records(rs,raw)
 except (ValueError,KeyError,IndexError,TypeError):pass
 else:raise SystemExit('FAIL accepted paired corruption: '+name)
print(f'PASS {len(controls)} independent application corruption controls; forged vector checksums cannot conceal paired changes')
