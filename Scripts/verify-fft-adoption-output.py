#!/usr/bin/env python3
"""Complete app conformance plus independent decay and full sparse convolution/mix references."""
import argparse,hashlib,json,math,struct
from pathlib import Path
BASE='2bc11ed6a033e8642de4018e8e9ae9cfb4e1151c'
PINS={'original':{'version':'0.1.0-alpha.12','revision':'f464e04866903bfc7c9ce94c34d31125a776d270'},'shared':{'version':'0.1.0-alpha.17','revision':'e94d329c55495ca561306174d624eadf5c8e7da0'}}
def need(ok,message):
 if not ok:raise ValueError(message)
def f32(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def near(a,b,epsilon=2e-6):
 need(len(a)==len(b),'full scalar reference length')
 for x,y in zip(a,b):
  need((x==y) or (math.isfinite(x) and math.isfinite(y) and abs(x-y)<=epsilon*max(1,abs(y))),f'scalar value {x} != {y}')
def expected():
 d={}
 for rate in [8000,48000]:
  for frames in [65,1025]:
   for cutoff in [0,80]:
    for profile in ['equal','varying']:d[f'bands/{rate}/{frames}/{cutoff}/{profile}']={'kind':'bands','rate':rate,'frames':frames,'cutoff':cutoff,'profile':profile}
  for count in [65,1025,4097]:
   for band in range(8):d[f'decay/{rate}/{count}/{band}']={'kind':'decay','rate':rate,'count':count,'band':band}
   d[f'comparison/{rate}/{count}']={'kind':'comparison','rate':rate,'count':count}
  for profile in ['clicks','burst']:
   for receivers in [1,2]:d[f'audition/{rate}/{profile}/{receivers}']={'kind':'audition','rate':rate,'profile':profile,'receivers':receivers}
  for cutoff in [0,80]:d[f'generator/{rate}/{cutoff}']={'kind':'generator','rate':rate,'cutoff':cutoff,'frames':round(.04*rate)}
  d[f'drivers/{rate}']={'kind':'drivers','rate':rate,'frames':round(.04*rate)}
 return d
class Native:
 def __init__(self,data):self.data=data;self.spans=[];self.total=0
 def vector(self,v):
  need(set(v)=={'offset','count','width','sha256'},'native vector schema')
  o,n,w=v['offset'],v['count'],v['width'];need(w in [32,64] and isinstance(o,int) and isinstance(n,int) and o>=0 and n>=0,'native layout')
  end=o+n*(w//8);need(end<=len(self.data),'truncated native buffer');chunk=self.data[o:end]
  need(hashlib.sha256(chunk).hexdigest()==v['sha256'],'native vector hash')
  self.spans.append((o,end));self.total+=n
  return [x[0] for x in struct.iter_unpack('<d' if w==64 else '<f',chunk)]
 def complete(self):
  at=0
  for a,b in sorted(self.spans):need(a==at,'gap/overlap/duplicate native vector');at=b
  need(at==len(self.data),'unclaimed native tail')
def verify_records(records,data):
 spec=expected();ids=[r['id'] for r in records]
 need(len(ids)==len(set(ids)) and set(ids)==set(spec),'complete unique application case tree')
 native=Native(data)
 for c in records:
  need(all(c[k]==v for k,v in spec[c['id']].items()),'case parameter identity')
  kind=c['kind'];rate=c['rate']
  def vec(v,width=32):
   need(v['width']==width,'native field precision');return native.vector(v)
  if kind=='bands':
   need(len(c['arrivals'])==4,'complete arrivals')
   for j,(arrival,sample) in enumerate(zip(c['arrivals'],[0,.37,12.25,c['frames']-1-.61])):
    need(arrival['sample']==sample,'arrival phase')
    gains=vec(arrival['gains'],64);need(gains==[.125 if c['profile']=='equal' else ((b+j*3)%7-3)/16 for b in range(8)],'all octave gains')
   y=vec(c['output']);need(len(y)==c['frames'] and all(math.isfinite(x) for x in y),'full band output')
  elif kind in ['decay','comparison']:
   count=c['count'];x=vec(c['input']);need(len(x)==count,'full decay input')
   near(x,[f32(((i*7)%31-15)/32*math.exp(-i/max(1,count//6))) for i in range(count)],epsilon=2e-7)
   if kind=='decay':
    rendered=vec(c['rendered']);measured=vec(c['measured']);curve=vec(c['curve'],64)
    need(len(rendered)==len(measured)==len(curve)==count,'complete octave arrays')
    remaining=[];total=0
    for value in reversed(rendered):total+=value*value;remaining.append(total)
    remaining.reverse()
    ref=[(10*math.log10(max(v,math.ulp(0.0))/remaining[0]) if max(v,math.ulp(0.0))/remaining[0]>0 else -math.inf) for v in remaining] if total>0 else [-math.inf]*count
    near(curve,ref,epsilon=2e-12)
    first=next((i for i,v in enumerate(ref) if v<=-5),None);last=next((i for i,v in enumerate(ref) if v<=-35),None)
    rt=None
    if first is not None and last is not None and last>first+1:
     times=[i/rate for i in range(first,last+1)];ys=ref[first:last+1];n=len(times);sx=sum(times);sy=sum(ys);sxx=sum(t*t for t in times);sxy=sum(t*y for t,y in zip(times,ys))
     slope=(n*sxy-sx*sy)/(n*sxx-sx*sx);rt=-60/slope if slope<0 else None
    if rt is None:need(c['rt']=='nil','unavailable fitted RT')
    else:near([float(c['rt'])],[rt],epsilon=2e-10)
   else:
    frequencies=vec(c['frequencies'],64);levels=vec(c['levels'],64);fine=vec(c['fine'],64);early=vec(c['early'],64);energy=vec(c['energy'],64)
    points=round(math.log2((rate*.4)/80)*12)+1
    near(frequencies,[80*2**(j/12) for j in range(points)],epsilon=2e-12)
    need(len(levels)==len(fine)==points and len(early)==18 and len(energy)==30,'complete comparison arrays')
    near(fine,[v-sum(levels[max(i-6,0):min(i+7,len(levels))])/len(levels[max(i-6,0):min(i+7,len(levels))]) for i,v in enumerate(levels)],epsilon=2e-12)
    near([float(c['correlation'])],[1],epsilon=2e-12)
    need(all(math.isfinite(x) and x>=0 for x in energy),'finite energy-time bins')
  elif kind=='audition':
   clip=vec(c['clip']);responses=[vec(v) for v in c['responses']];dry=[vec(v) for v in c['dry']];wet=[vec(v) for v in c['wet']]
   count=rate*4 if c['profile']=='clicks' else rate*5//2;need(len(clip)==count,'complete production dry clip')
   need(len(responses)==c['receivers'] and len(dry)==len(wet)==2,'all preview channels')
   paths=[0,0] if c['receivers']==1 else [0,1]
   for channel,r in enumerate(responses):need(r==[f32(((j*3+channel*7)%17-8)/16) if j in [0,4,64,127,256] else 0 for j in range(257)],'full sparse response and endpoint identity')
   for channel,path in enumerate(paths):
    need(dry[channel]==clip+[0]*256,'full dry padding')
    taps=[(i,v) for i,v in enumerate(responses[path]) if v]
    ref=[sum(clip[j-k]*v for k,v in taps if 0<=j-k<count) for j in range(count+256)]
    near(wet[channel],ref,epsilon=3e-6)
   dry_energy=sum(v*v for row in dry for v in row);wet_energy=sum(v*v for row in wet for v in row)
   matching=f32(math.sqrt(dry_energy/wet_energy)) if wet_energy>0 else 1
   near([float(c['matchingGain'])],[matching],epsilon=2e-6)
   dp=max(map(abs,clip));wp=max(abs(x) for row in wet for x in row)
   need(float(c['dryPeak'])==dp and float(c['wetPeak'])==wp,'complete actual peaks')
   need(len(c['mixes'])==6 and {(m['match'],float(m['mix'])) for m in c['mixes']}=={(match,f32(mix)) for match in [False,True] for mix in [0,.3,1]},'all mixes')
   for m in c['mixes']:
    mix=float(m['mix']);gain=matching if m['match'] else 1
    loudest=max(dp,f32(wp*gain));output=min(1,f32(f32(.9)/loudest)) if loudest>0 else 1
    dg=f32(f32(1-mix)*output);wg=f32(f32(mix*gain)*output)
    ys=[vec(v) for v in m['channels']];need(len(ys)==2,'mix channels')
    for y,d,w in zip(ys,dry,wet):near(y,[f32(f32(dg*a)+f32(wg*b)) for a,b in zip(d,w)],epsilon=2e-6)
  else:
   if kind=='drivers':need(vec(c['crossovers'],64)==[600],'driver crossover contract')
   ys=[vec(v) for v in c['channels']];need(len(ys)==2 and all(len(y)==c['frames'] and all(math.isfinite(x) for x in y) for y in ys),'complete generated channels')
 native.complete();return len(records),native.total,len(data)
def verify(root):
 root=Path(root);env=json.loads((root/'environment.json').read_text());need(env['workingTreeDirty'] is False and env['baseline']==BASE,'producer source scope')
 reports=[];data=[];counts=[]
 for mode in ['original','shared']:
  p=root/mode;records=json.loads((p/'application.json').read_text());raw=(p/'native.bin').read_bytes();counts.append(verify_records(records,raw));reports.append(records);data.append(raw)
  pins=[x for x in json.loads((p/'consumer-Package.resolved').read_text())['pins'] if x['identity']=='continuumkit'];need(len(pins)==1 and pins[0]['state']==PINS[mode],'immutable old/new core source pins')
 need(reports[0]==reports[1] and data[0]==data[1],'complete original/shared native conformance')
 need(counts[0]==counts[1],'native scope parity');return counts[0]
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('output');args=parser.parse_args()
 try:
  cases,values,bytes_=verify(args.output);print(f'PASS {cases} complete application records, {values} native values, {bytes_} bytes per variant; exact original/shared arrays and independent complete decay/convolution/mix references')
 except (ValueError,KeyError,TypeError,IndexError) as e:raise SystemExit(f'FAIL FFT app adoption: {e}')
