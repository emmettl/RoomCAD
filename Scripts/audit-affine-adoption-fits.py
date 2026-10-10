#!/usr/bin/env python3
"""Exact-native fit-only audit; this is not the complete application adoption gate."""
import argparse,hashlib,json,math,struct
from fractions import Fraction as F
from pathlib import Path
EPS=2**-52
p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path);p.add_argument('--mode',choices=['original','shared'],required=True);a=p.parse_args()
r=a.output;report=json.loads((r/'application.json').read_text());raw=(r/'native.bin').read_bytes()
def need(ok,message):
 if not ok:raise ValueError(message)
def scalar(row):
 bits=int(row['bits'],16);value=struct.unpack('<d',bits.to_bytes(8,'little'))[0];shown=float(row['value'])
 need((math.isnan(value) and math.isnan(shown)) or value==shown,'scalar native representation')
 return value
def vector(row):
 width=row['width'];need(width in [32,64],'native width');start=row['offset'];end=start+row['count']*(width//8)
 need(0<=start<=end<=len(raw),'native vector completeness');data=memoryview(raw)[start:end]
 need(hashlib.sha256(data).hexdigest()==row['sha256'],'native vector hash')
 return [v[0] for v in struct.iter_unpack('<d' if width==64 else '<f',data)]
def close(value,reference,scale,eps):
 if not math.isfinite(value) or not math.isfinite(reference):return False
 return abs(value-reference)<=max(4*math.ulp(reference),eps*EPS*scale)
rows=[];predictions=0;maximum=0.0
for event in report['events']:
 if event['kind'] not in ['index-fit','time-fit']:continue
 x,y=vector(event['x']),vector(event['y']);need(len(x)==len(y)>=2 and all(math.isfinite(v) for v in x+y),'finite dimensions')
 xs=list(map(F.from_float,x));ys=list(map(F.from_float,y));n=len(x);sx=sum(xs);sy=sum(ys);sxx=sum(v*v for v in xs);sxy=sum(v*w for v,w in zip(xs,ys));den=n*sxx-sx*sx
 need(den>0,'actual selected native rank');m=(n*sxy-sx*sy)/den;b=(sy-m*sx)/n;want=float(m)
 need('unavailable' not in event,'unexpected unavailable supported window')
 slope=scalar(event['slope']);scale=max(map(abs,y));agrees=close(slope,want,abs(want),128)
 category='reference_agreement' if agrees else 'original_inaccurate' if math.isfinite(slope) else 'original_nonfinite'
 if a.mode=='shared':
  need(agrees,'shared slope accuracy '+event['case']+':'+str(event['sequence']))
  origin=scalar(event['origin']);anchor=scalar(event['valueAtOrigin']);need(origin==x[0],'application shifted coordinate origin')
  anchorWant=float(b+m*F.from_float(origin));need(close(anchor,anchorWant,max(scale,abs(anchorWant)),128),'shared origin ordinate')
  values=vector(event['diagnosticPredictions']);need(len(values)==len(x),'complete diagnostic predictions')
  for coordinate,value in zip(xs,values):
   expected=float(b+m*coordinate);need(close(value,expected,max(scale,abs(expected)),256),'shared complete prediction accuracy')
  predictions+=len(values)
  if want!=0:maximum=max(maximum,abs(slope-want)/abs(want))
 rows.append({'case':event['case'],'part':event['part'],'sequence':event['sequence'],'kind':event['kind'],'count':n,'exactNativeSlope':str(m),'classification':category})
summary={'schemaVersion':1,'scope':'fit coefficients/origin/complete diagnostic predictions only; application window/noise/tail/calibration and corruption gates pending','mode':a.mode,'casesCaptured':len(report['cases']),'fitRecords':len(rows),'classifications':{k:sum(x['classification']==k for x in rows) for k in sorted({x['classification'] for x in rows})},'completeSharedPredictions':predictions,'maximumSharedRelativeSlopeError':maximum,'applicationAdoptionAccepted':False,'fits':rows}
(r/'fit-audit.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
print('PASS exact-native fit-only audit',a.mode,len(rows),'records;',predictions,'complete shared predictions; full application adoption remains pending')
