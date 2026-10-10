#!/usr/bin/env python3
"""Independent complete native window/noise/tail/calibration/summary adoption gate."""
import argparse,cmath,copy,gzip,hashlib,json,math,struct,subprocess,sys
from fractions import Fraction as F
from pathlib import Path
sys.dont_write_bytecode=True
EPS=2**-52
PINS={'original':{'version':'0.1.0-alpha.17','revision':'e94d329c55495ca561306174d624eadf5c8e7da0'},'shared':{'version':'0.1.0-alpha.18','revision':'0e0929f4a0806940ed2fc5be5f81d1a82034cc8c'}}
def need(ok,msg):
 if not ok:raise ValueError(msg)
def scalar(v):
 need(set(v)=={'bits','value'},'scalar schema');bits=int(v['bits'],16);n=struct.unpack('<d',bits.to_bytes(8,'little'))[0];shown=float(v['value'])
 need((math.isnan(n) and math.isnan(shown)) or n==shown,'coherent scalar bits');return n
def near(a,b,scale=None,eps=512):
 if a==b or (math.isnan(a) and math.isnan(b)):return
 need(math.isfinite(a) and math.isfinite(b),'finite category mismatch')
 need(abs(a-b)<=max(4*math.ulp(b),eps*EPS*(max(abs(b),1) if scale is None else scale)),f'reference {a} != {b}')
def option(a,b):
 if b is None:need(a is None,'unavailable parameter')
 else:need(a is not None,'missing parameter');near(scalar(a),b)
def ieee_div(a,b):
 if b!=0:return a/b
 if a==0:return math.nan
 return math.copysign(math.inf,a*math.copysign(1,b))
def log10(a):return math.log10(a) if a>0 else -math.inf if a==0 else math.nan
def f32(x):return struct.unpack('<f',struct.pack('<f',x))[0]
def backwards(energy,tail=0):
 # Compensated independent sum reference, rather than app's serial naive sum.
 result=[];total=tail;correction=0.0
 for x in reversed(energy):
  y=total+x;correction+=(total-y)+x if abs(total)>=abs(x) else (x-y)+total;total=y;result.append(total+correction)
 return result[::-1]
def fft(values,inverse=False):
 a=list(map(complex,values));n=len(a);need(n>=2 and n&(n-1)==0,'radix two reference size');j=0
 for i in range(1,n):
  bit=n>>1
  while j&bit:j^=bit;bit>>=1
  j^=bit
  if i<j:a[i],a[j]=a[j],a[i]
 size=2
 while size<=n:
  roots=[cmath.exp((2 if inverse else -2)*math.pi*1j*k/size) for k in range(size//2)]
  for start in range(0,n,size):
   for k,w in enumerate(roots):
    u=a[start+k];v=a[start+k+size//2]*w;a[start+k]=u+v;a[start+k+size//2]=u-v
  size*=2
 return [x/n for x in a] if inverse else a
try:
 import numpy as np
except ImportError:np=None
FFT_CACHE={};FIT_CACHE={};PRED_CACHE=set();FILTER_CACHE={};GAIN_CACHE={}
def transform(values):
 return list(np.fft.fft(values)) if np is not None else fft(values)
def rise(f,c):
 if f<=0:return 0.0
 x=math.log2(f/c)
 return 0.0 if x<=-.5 else 1.0 if x>=.5 else .5-.5*math.cos(math.pi*(x+.5))
def weight(b,f,measured):
 centres=[1000*2**i for i in range(-4,4)];cross=[math.sqrt(x*y) for x,y in zip(centres,centres[1:])]
 value=(1 if b==0 else rise(f,cross[b-1]))*(1 if b==7 else 1-rise(f,cross[b]))
 if measured and b==0:value*=rise(f,centres[0]/math.sqrt(2))
 if measured and b==7:value*=1-rise(f,centres[7]*math.sqrt(2))
 return value
def filtered(samples,rate,band=None,measured=False,highpass=None):
 key=(hashlib.sha256(memoryview(samples).cast('B')).hexdigest(),len(samples));cachekey=(key,rate,band,measured,highpass)
 if cachekey in FILTER_CACHE:return FILTER_CACHE[cachekey]
 n=2
 while n<len(samples)+16384:n*=2
 fk=(key,n)
 if fk not in FFT_CACHE:FFT_CACHE[fk]=transform(list(samples)+[0]*(n-len(samples)))
 spectrum=FFT_CACHE[fk];gk=(n,rate,band,measured,highpass)
 if gk not in GAIN_CACHE:GAIN_CACHE[gk]=[rise(min(k,n-k)*rate/n,highpass) if highpass is not None else weight(band,min(k,n-k)*rate/n,measured) for k in range(n)]
 gains=GAIN_CACHE[gk]
 values=[a*b for a,b in zip(spectrum,gains)]
 output=list(np.fft.ifft(values)) if np is not None else fft(values,True)
 FILTER_CACHE[cachekey]=[f32(x.real) for x in output[:len(samples)]]
 return FILTER_CACHE[cachekey]
def compare_filter(actual,expected,peak):
 need(len(actual)==len(expected),'complete filtered length')
 for a,b in zip(actual,expected):need(abs(a-b)<=max(8*math.ulp(b),2e-6*max(peak,1e-30)),'independent full octave/filter reference')
class Native:
 def __init__(self,report,raw):
  self.raw=raw;self.cache={};spans=[];self.values=0
  def walk(x):
   if isinstance(x,dict):
    if set(x)=={'offset','count','width','sha256'}:
     o,n,w=x['offset'],x['count'],x['width'];need(type(o)==type(n)==int and o>=0 and n>=0 and w in [32,64],'vector dimensions');end=o+n*(w//8);need(end<=len(raw),'complete native buffer');chunk=memoryview(raw)[o:end];need(hashlib.sha256(chunk).hexdigest()==x['sha256'],'native vector hash');self.cache[o]=chunk.cast('d' if w==64 else 'f');spans.append((o,end));self.values+=n
    elif set(x)=={'bits','value'}:scalar(x)
    else:
     for v in x.values():walk(v)
   elif isinstance(x,list):
    for v in x:walk(v)
  walk(report);at=0
  for a,b in sorted(spans):need(a==at,'missing/overlapping/duplicate native vector');at=b
  need(at==len(raw),'unclaimed native buffer tail')
 def vec(self,d,width=64):need(d['width']==width,'native field precision');return self.cache[d['offset']]
 def array(self,d,expected,width=64,eps=512):
  actual=self.vec(d,width);need(len(actual)==len(expected),'complete reference vector')
  for a,b in zip(actual,expected):near(a,b,eps=eps)
  return actual
class Stream:
 def __init__(self,rows):self.rows=rows;self.at=0
 def peek(self):return self.rows[self.at]['kind'] if self.at<len(self.rows) else None
 def take(self,kind):
  need(self.peek()==kind,'event order/completeness '+kind+' at '+str(self.at));row=self.rows[self.at];self.at+=1;return row
 def done(self):need(self.at==len(self.rows),'unexpected/unconsumed event')
class Policy:
 def __init__(self,report,raw,mode):
  self.report=report;self.n=Native(report,raw);self.mode=mode;self.groups={};self.fit_count=0;self.noise_count=0
  expected=[]
  for rate in [8000,48000]:
   for comp in ['false','true']:expected.append(f'analytic/{rate}/{comp}')
  for burst in ['false','true']:
   for comp in ['false','true']:expected.append(f'noise/{burst}/{comp}')
  expected+=['silent','short']+[f'threshold/{i}' for i in [7,8,9]]+[f'probe/index/{i}' for i in [0,1000000000]]+[f'time/delayed/{i}' for i in [0,480000]]+[f'time/unavailable/{i}' for i in [0,48000]]+[f'band/{b}/{m}' for b in range(8) for m in ['false','true']]+['wave/generated/cpu','wave/generated/metal','calibration/geometrical','calibration/erratic-band']
  need([c['id'] for c in report['cases']]==expected,'complete ordered unique case tree')
  for i,e in enumerate(report['events']):
   need(e['sequence']==i and e['case'] in expected,'event sequence/case identity');self.groups.setdefault((e['case'],e['part']),[]).append(e)
  self.used=set()
 def stream(self,c,part):
  key=(c['id'],part);self.used.add(key);return Stream(self.groups.get(key,[]))
 def fit(self,s,kind,x,y):
  row=s.take(kind);actualx=self.n.array(row['x'],x);actualy=self.n.array(row['y'],y)
  need(list(actualx)==list(x) and list(actualy)==list(y),'exact actual selected native fit input')
  key=(row['x']['sha256'],row['y']['sha256'])
  if key not in FIT_CACHE:
   xs=list(map(F.from_float,x));ys=list(map(F.from_float,y));n=len(x);sx=sum(xs);sy=sum(ys);den=n*sum(v*v for v in xs)-sx*sx;need(den>0,'selected native rank');m=(n*sum(v*w for v,w in zip(xs,ys))-sx*sy)/den;b=(sy-m*sx)/n;FIT_CACHE[key]=(m,b)
  m,b=FIT_CACHE[key];slope=scalar(row['slope']);scale=max(map(abs,y));self.fit_count+=1
  if self.mode=='shared':
   near(slope,float(m),abs(float(m)),128)
   if kind=='index-fit':
    scaleX=max(abs(w-x[0]) for w in x);nx=[(v-x[0])/scaleX for v in x];scaleY=max(abs(w-y[0]) for w in y);ny=[(v-y[0])/scaleY if scaleY else 0 for v in y];mx=math.fsum(nx)/len(nx);my=math.fsum(ny)/len(ny);variance=math.fsum((v-mx)**2 for v in nx);terms=[(v-mx)*(w-my) for v,w in zip(nx,ny)];cov=math.fsum(terms);absolute=math.fsum(map(abs,terms));ratio=1 if absolute==0 else math.inf if cov==0 else absolute/abs(cov)
    near(scalar(row['normalizedVariance']),variance,abs(variance));near(scalar(row['covarianceCancellationRatio']),ratio,abs(ratio) if math.isfinite(ratio) else None)
   need(scalar(row['origin'])==x[0],'fit origin identity');near(scalar(row['valueAtOrigin']),float(b+m*F.from_float(x[0])),scale,128)
   pred=self.n.vec(row['diagnosticPredictions']);need(len(pred)==len(x),'complete predictions');pk=key+(row['diagnosticPredictions']['sha256'],)
   if pk not in PRED_CACHE:
    for value,coordinate in zip(pred,x):near(value,float(b+m*F.from_float(coordinate)),scale,256)
    PRED_CACHE.add(pk)
  else:
   sx=sy=sxx=sxy=0.0
   for v,w in zip(x,y):sx+=v;sy+=w;sxx+=v*v;sxy+=v*w
   legacy=ieee_div(len(x)*sxy-sx*sy,len(x)*sxx-sx*sx);near(slope,legacy,abs(legacy) if math.isfinite(legacy) else None,8)
   intercept=ieee_div(sy-slope*sx,len(x));captured=scalar(row['intercept'] if 'intercept' in row else row['diagnosticIntercept']);near(captured,intercept)
   pred=self.n.vec(row['diagnosticPredictions']);need(len(pred)==len(x),'complete original diagnostic line')
   for value,coordinate in zip(pred,x):near(value,captured+slope*coordinate)
  return row,slope
 def noise(self,s,energy,rate):
  block=max(int(.01*rate),1);blocks=len(energy)//block
  if blocks<=20:return None
  def floor_record(index):
   row=s.take('noise-floor');start=max(min(index,blocks-blocks//10),blocks//2);need(row['index']==index and row['start']==start,'noise floor clamp');mean=math.fsum(energy[start*block:])/(len(energy)-start*block);near(scalar(row['mean']),mean,abs(mean));return 10*log10(max(scalar(row['mean']),1e-300))
  floor=floor_record(blocks-blocks//10);setup=s.take('noise-setup');need(setup['block']==block and setup['blocks']==blocks,'noise block dimensions')
  means=self.n.array(setup['means'],[math.fsum(energy[i*block:(i+1)*block])/block for i in range(blocks)])
  levels=self.n.array(setup['levels'],[10*log10(max(v,1e-300)) for v in means]);smooth=self.n.array(setup['smoothed'],[10*log10(max(math.fsum(means[max(i-2,0):min(i+3,blocks)])/len(means[max(i-2,0):min(i+3,blocks)]),1e-300)) for i in range(blocks)])
  top=max(levels);near(scalar(setup['top']),top);near(scalar(setup['floor']),floor)
  if top-floor<=20:return None
  for iteration in range(5):
   first=next((i for i,v in enumerate(levels) if v<=top-5),None)
   if first is None:return None
   last=next((i for i in range(first+1,blocks) if smooth[i]<floor+10),blocks)-1
   window=s.take('noise-window');need(window['first']==first and window['last']==last,'noise selected window');near(scalar(window['floor']),floor);near(scalar(window['top']),top)
   if last<=first+2:return None
   fit,slope=self.fit(s,'index-fit',[float(i) for i in range(first,last+1)],list(levels[first:last+1]));need(fit['offset']==first,'noise fit coordinate offset')
   if slope>=0:return None
   crossing=s.take('noise-crossing');coordinate=scalar(crossing['coordinate'])
   if self.mode=='shared':
    expected=float((F.from_float(floor)-F.from_float(scalar(fit['valueAtOrigin'])))/F.from_float(slope)+F.from_float(scalar(fit['origin'])))
    near(coordinate,expected,max(abs(expected),1),256);cut=int(min(max(coordinate,last),blocks-1));start=min(cut+int(5/-slope)+1,blocks-blocks//10);need(crossing['nextStart']==start,'bounded noise start')
   else:
    near(coordinate,(floor-scalar(fit['intercept']))/slope);cut=min(max(int(coordinate),last),blocks-1);start=cut+int(5/-slope)+1;need(crossing['nextStart'] is None,'original crossing binding')
   need(crossing['cut']==cut,'noise crossing truncation/clamp');floor=floor_record(start);row=s.take('noise-iteration');need(row['crossing']==cut,'iteration crossing');near(scalar(row['slope']),slope);near(scalar(row['nextFloor']),floor);self.noise_count+=1
  tail=s.take('noise-tail');index=cut*block;need(tail['index']==index,'noise cut index')
  level=float(F.from_float(scalar(fit['valueAtOrigin']))+F.from_float(slope)*F.from_float(cut-scalar(fit['origin']))) if self.mode=='shared' else scalar(fit['intercept'])+slope*cut
  near(scalar(tail['level']),level);per=10**(scalar(tail['level'])/10);tau=10/(math.log(10)*-slope)*block;near(scalar(tail['perSample']),per,abs(per));near(scalar(tail['tau']),tau);near(scalar(tail['tail']),per*tau,abs(per*tau))
  return index,scalar(tail['tail'])
 def room(self,s):
  row=s.take('room-energy');energy=self.n.vec(row['energy']);rate=row['sampleRate'];end=len(energy);tail=0.0
  if row['noiseCompensated']:
   cut=self.noise(s,energy,rate)
   if cut is not None:end,tail=cut
  c=s.take('room-curve');need(c['end']==end,'integration cut');near(scalar(c['tail']),tail,abs(tail));curve=self.n.array(c['curve'],backwards(energy[:end],tail));total=curve[0] if end else 0.0;near(scalar(c['total']),total,abs(total));db=self.n.array(c['decibels'],[10*log10(ieee_div(max(v,math.ulp(0.0)),total)) for v in curve])
  times={}
  for name,upper,lower in [('edt',0,-10),('t20',-5,-25),('t30',-5,-35)]:
   first=next((i for i,v in enumerate(db) if v<=upper),None);last=next((i for i,v in enumerate(db) if v<=lower),None);value=None
   if first is not None and last is not None and last>first+1:
    win=s.take('room-window');need(win['first']==first and win['last']==last,'EDT/T20/T30 native selection');near(scalar(win['upper']),upper);near(scalar(win['lower']),lower);near(scalar(win['rate']),rate);self.n.array(win['values'],db[first:last+1])
    fit,slope=self.fit(s,'index-fit',[float(i) for i in range(first,last+1)],list(db[first:last+1]));need(fit['offset']==first,'sample coordinate offset');slope*=rate;value=-60/slope if slope<0 else None
   times[name]=value
  # Clarity's denominator can be singular when all energy is early. Its
  # declared forward IEEE fold is part of the retained app policy; fsum can
  # change finite/infinite categories even though it is a better real sum.
  e50=sum(energy[:min(int(.05*rate),end)]);e80=sum(energy[:min(int(.08*rate),end)]);moment=math.fsum(i/rate*v for i,v in enumerate(energy[:end]))
  times.update(c50=10*log10(ieee_div(e50,max(total-e50,math.ulp(0.0)))),c80=10*log10(ieee_div(e80,max(total-e80,math.ulp(0.0)))),d50=ieee_div(e50,total),centreTime=moment/max(total-tail,math.ulp(0.0)))
  return energy,times
 def decay(self,s,samples=None,rate=48000):
  if s.peek()!='decay-window':
   need(samples is not None and not any(samples),'missing valid decay-window');return None
  row=s.take('decay-window');actual=self.n.vec(row['samples'],32)
  if samples is not None:compare_filter(actual,samples,max(map(abs,samples),default=0))
  need(row['sampleRate']==rate,'decay coordinate rate');curve=backwards([v*v for v in actual]);total=curve[0];reference=[10*log10(max(v,math.ulp(0.0))/total) for v in curve];db=self.n.array(row['curve'],reference)
  upper,lower=scalar(row['upper']),scalar(row['lower']);need((upper,lower)==(-5,-35),'time decay thresholds');first=next((i for i,v in enumerate(db) if v<=upper),None);last=next((i for i,v in enumerate(db) if v<=lower),None);need(row['first']==first and row['last']==last and last>first+1,'time native window selection')
  fit,slope=self.fit(s,'time-fit',[i/rate for i in range(first,last+1)],list(db[first:last+1]));need(fit['first']==first and fit['last']==last and fit['sampleRate']==rate,'time fit binding')
  return -60/slope if slope<0 else None
 def params(self,record,reference):
  need(set(record)==set(reference),'complete room parameters')
  for k,v in reference.items():option(record[k],v)
 def scaled_room(self,actual,base,factors):
  need(set(actual)==set(base),'room metadata tree');need(actual['size']==base['size'],'room dimensions')
  for side in ['west','east','north','south','floor','ceiling']:
   need({k:v for k,v in actual[side].items() if k!='absorption'}=={k:v for k,v in base[side].items() if k!='absorption'},'material metadata/scattering')
   for a,b,f in zip(actual[side]['absorption'],base[side]['absorption'],factors):near(a,min(b*f,.99))
 def calibration(self,c):
  model=c['model'];need(model in ['geometrical','erratic-band'] and c['id']=='calibration/'+model,'calibration identity');target=[None if x is None else scalar(x) for x in c['target']];need(target==([None,None,1.2,1.2,1.2,1.2,None,None] if model=='geometrical' else [1.2,None,None,1,1,1,1,1]),'calibration target');tol=c['tolerance'];need(tol==(.03 if model=='geometrical' else .01),'calibration tolerance');steps=c['steps'];trials=c['trials'];need(len(steps)==len(trials) and 1<=len(steps)<=6,'complete trial/step tree');base=c['settings']['room'];factors=[1.0]*8;history=[]
  for i,(trial,step) in enumerate(zip(trials,steps)):
   if model=='geometrical':self.metadata(trial['metadata'],trial['settings'])
   need(trial['call']==i,'trial call');current=self.n.array(step['factors'],factors);need(len(current)==8,'complete factor vector');self.scaled_room(trial['settings']['room'],base,current);need({k:v for k,v in trial['settings'].items() if k!='room'}=={k:v for k,v in c['settings'].items() if k!='room'},'trial nonmaterial settings')
   stream=self.stream(c,'measure-'+str(i));channels=[self.n.vec(v,32) for v in trial['channels']];need(len(channels)==1 and len(channels[0])==int(c['settings']['sampleRate']*c['settings']['duration']),'full calibration channels');times=[]
   for band in range(8):times.append(self.decay(stream,filtered(channels[0],48000,band,True)))
   stream.done();need(len(step['reverberationTime'])==8,'step times');[option(a,b) for a,b in zip(step['reverberationTime'],times)];history.append((list(current),times))
   done=all(g is None or t is None or abs(t/g-1)<=tol for g,t in zip(target,times))
   if i==len(steps)-1:need(done or i==5,'premature feedback stop');break
   need(not done,'extra feedback after convergence')
   for band,(goal,time) in enumerate(zip(target,times)):
    if goal is None or time is None:continue
    ratio=time/goal
    if i>0 and history[i-1][1][band] is not None and history[i-1][0][band]!=current[band] and history[i-1][1][band]!=time:
     before=history[i-1][1][band];power=-math.log(time/before)/math.log(current[band]/history[i-1][0][band])
     if power>=.3:ratio=(time/goal)**(1/min(power,1.5))
    limit=.99/min(base[side]['absorption'][band] for side in ['west','east','north','south','floor','ceiling'] if base[side]['absorption'][band]>0)
    factors[band]=min(max(current[band]*min(max(ratio,.5),2),0),limit)
  bestF=list(history[0][0]);bestT=list(history[0][1])
  for band,goal in enumerate(target):
   if goal is not None:
    selected=min(history,key=lambda h:abs((h[1][band] if h[1][band] is not None else math.inf)/goal-1));bestF[band]=selected[0][band];bestT[band]=selected[1][band]
  self.n.array(c['best']['factors'],bestF);[option(a,b) for a,b in zip(c['best']['reverberationTime'],bestT)];self.scaled_room(c['room'],base,bestF)
 def summary(self,c,channels):
  settings=c['settings'];rate=settings['sampleRate'];samples=channels[0];summary=c['summary'];channel=summary['channels'][0]
  speed=331.3*math.sqrt((settings['atmosphere']['temperatureCelsius']+273.15)/273.15)
  source=settings['source']['position'];receiver=settings['receivers'][0]['position'];direct=math.sqrt(sum((a-b)**2 for a,b in zip(source,receiver)))/speed;duration=min(direct+.08,len(samples)/rate)
  near(scalar(summary['earlyDuration']),duration);need(channel['name']=='R','summary channel metadata');peak=max(map(abs,samples));size=max(1,(len(samples)+399)//400)
  self.n.array(channel['envelope'],[max(-90,20*log10(max(max(map(abs,samples[i:i+size])),1e-12)/peak)) for i in range(0,len(samples),size)])
  n=2
  while n<len(samples):n*=2
  spectrum=transform(list(samples)+[0]*(n-len(samples)));spacing=rate/n;bins=min(int((20*2**10)*2**(1/6)/spacing)+2,n//2);power=[0]+[abs(z)**2 for z in spectrum[1:bins]];levels=[]
  for f in [20*2**(i/12) for i in range(121)]:
   lower=max(math.floor(f*2**(-1/12)/spacing+.5),1);upper=min(max(math.floor(f*2**(1/12)/spacing+.5),lower),len(power)-1);levels.append(10*log10(max(math.fsum(power[lower:upper+1])/(upper-lower+1),1e-300)))
  actual=self.n.vec(channel['spectrum']);need(len(actual)==121,'full spectrum summary')
  for a,b in zip(actual,[max(v-max(levels),-90) for v in levels]):need(abs(a-b)<=2e-5,'independent full summary spectrum')
  count=min(int(duration*rate)+2048,len(samples));highs=filtered(samples[:count],rate,highpass=500);energy=[0.0]*math.ceil(duration/.00025)
  for i,v in enumerate(highs):
   at=int(i/rate/.00025)
   if at<len(energy):energy[at]+=v*v
  expected=[max(10*log10(max(v,math.ulp(0.0))/max(max(energy),math.ulp(0.0))),-90) for v in energy];actual=self.n.vec(channel['early']);need(len(actual)==len(expected),'full early summary')
  for a,b in zip(actual,expected):need(abs(a-b)<=2e-5,'independent complete energy-time summary')
 def metadata(self,record,settings):
  need(record['sampleRate']==48000 and record['frameCount']==int(settings['duration']*48000) and record['encodingVersion']==1 and record['format']=='dev.roomcad.impulse-response','response metadata format')
  need(record['content']=='complete' and record['commonGain']==1 and record['emissionFrame']==0 and record['processing']==[],'response content/gain history')
  need(len(record['channels'])==1 and record['channels'][0]['sourceID']==settings['source']['id'] and record['channels'][0]['receiverID']==settings['receivers'][0]['id'] and record['channels'][0]['receiverPosition']==settings['receivers'][0]['position'],'response identities/coordinates')
  need(record['generator']=='RoomCAD hybrid model 7' and len(record['assumptions'])==9,'response model assumptions')
 def run(self):
  for c in self.report['cases']:
   family=c['family'];id=c['id'];self.current_case=id
   if family=='energy':
    energy=self.n.vec(c['energy']);s=self.stream(c,'measure');actual,params=self.room(s);need(list(actual)==list(energy),'root/actual energy identity');s.done();self.params(c['roomParameters'],params);s=self.stream(c,'noise-cut');cut=self.noise(s,energy,c['sampleRate']);s.done()
    if cut is None:need(c['noiseCut'] is None,'unavailable noise cut')
    else:need(c['noiseCut']['index']==cut[0],'root cut index');near(scalar(c['noiseCut']['tail']),cut[1],abs(cut[1]))
    if id.startswith('noise/'):
     burst=id.split('/')[1]=='true';comp=id.endswith('true');need(c['sampleRate']==48000 and c['noiseCompensated']==comp and len(energy)==144000,'noise case settings');need(c['parameters']=={'t60':1.2,'noiseDB':-45,'seconds':3,'lateBurst':burst,'seed':'9e3779b97f4a7c15'},'noise parameters')
     state=0x9e3779b97f4a7c15
     def random():
      nonlocal state
      state=(state*6364136223846793005+1442695040888963407)&((1<<64)-1)
      return (state>>11)/(1<<53)*2-1
     for i,v in enumerate(energy):
      sample=random()*math.exp(-3*math.log(10)/1.2*i/48000)+random()*10**(-45/20);expected=sample*sample
      if burst and 124800<=i<125280:expected*=10**1.5
      near(v,expected,max(expected,1e-30),256)
    if id.startswith('analytic/'):
     rate=int(id.split('/')[1]);need(c['sampleRate']==rate and len(energy)==3*rate and c['noiseCompensated']==id.endswith('true'),'analytic case parameters')
     for i,v in enumerate(energy):near(v,math.exp(-6*math.log(10)*i/rate/1.2),abs(v),128)
    elif id=='silent':need(list(energy)==[0]*64,'silent inputs')
    elif id=='short':need(list(energy)==[1,.1,.01],'short inputs')
    elif id.startswith('threshold/'):
     count=int(id.split('/')[1]);need(len(energy)==count,'threshold count');[near(v,10**(-i*.5)) for i,v in enumerate(energy)]
   elif family=='index-probe':
    offset=int(id.split('/')[-1]);need(c['offset']==offset,'probe offset');y=[-10-i/16 for i in range(8)];self.n.array(c['values'],y);s=self.stream(c,'index-probe');self.fit(s,'index-fit',[float(offset+i) for i in range(8)],y);s.done()
   elif family in ['time','time-unavailable']:
    samples=self.n.vec(c['samples'],32);s=self.stream(c,'reverberation');value=self.decay(s,samples,c['sampleRate']);s.done();option(c['rt'],value)
    if family=='time':
     delay=int(id.split('/')[-1]);need(c['delay']==delay and len(samples)==delay+24000 and c['t60']==.12,'delayed case');need(not any(samples[:delay]),'delayed zero prefix');compare_filter(samples[delay:],[f32(math.exp(-3*math.log(10)*i/48000/.12)) for i in range(24000)],1)
   elif family=='band':
    band=int(id.split('/')[1]);measured=id.endswith('true');need(c['band']==band and c['measuredWeight']==measured and c['sampleRate']==48000,'band identity');samples=self.n.vec(c['samples'],32)
    for i,v in enumerate(samples):
     t=i/48000;expected=f32((math.sin(2*math.pi*62.5*t)+math.sin(2*math.pi*8000*t)+.2*math.sin(2*math.pi*22*t)+.3*math.sin(2*math.pi*18000*t))*math.exp(-3*math.log(10)*t/.12));need(abs(v-expected)<=2e-6,'independent tone input identity')
    output=self.n.vec(c['filtered'],32);need(len(samples)==24000,'tone input length');compare_filter(output,filtered(samples,48000,band,measured),max(map(abs,samples)))
    onset=next(i for i,v in enumerate(output) if abs(v)>=.1*max(map(abs,output)));need(c['onset']==onset,'onset selection');energy=[v*v for v in output[onset:]];self.n.array(c['energy'],energy);s=self.stream(c,'reverberation');value=self.decay(s,output);s.done();option(c['rt'],value);s=self.stream(c,'measure');actual,params=self.room(s);need(list(actual)==list(energy),'band measured energy');s.done();self.params(c['roomParameters'],params)
   elif family=='calibration':self.calibration(c)
   elif family=='wave':
    need(c['settings']['room']['size']==[2,2,2] and c['settings']['crossoverFrequency']==80 and c['settings']['duration']==.4,'wave case settings');self.metadata(c['metadata'],c['settings']);need(c['backend']==id.split('/')[-1] and c['waveRuns']>0 and (c['gpuRuns']>0 if c['backend']=='metal' else c['gpuRuns']==0),'actual declared wave backend');channels=[self.n.vec(v,32) for v in c['channels']];need(len(channels)==1 and len(channels[0])==19200,'complete wave response');s=self.stream(c,'response-summary');times=[self.decay(s,filtered(channels[0],48000,b)) for b in range(8)];s.done();summary=c['summary'];near(scalar(summary['duration']),.4);need(len(summary['channels'])==1,'summary channels');[option(a,b) for a,b in zip(summary['channels'][0]['reverberationTime'],times)];self.summary(c,channels)
   else:raise ValueError('unknown case family')
  # Generation owns pre-fit normalization operations; validate every remaining
  # actual room measurement / fit stream, not just public final parameters.
  for key,rows in self.groups.items():
   if key in self.used:continue
   need(key[1] in ['generate'] or key[1].startswith('simulate-'),'unclaimed operation part');s=Stream(rows)
   while s.peek() is not None:
    need(s.peek()=='room-energy','unclaimed source-bound operation');self.room(s)
   s.done()
  need(self.fit_count==260 and self.noise_count==60,'complete declared fit/iteration matrix')
  return {'cases':39,'events':len(self.report['events']),'fits':self.fit_count,'noiseIterations':self.noise_count,'nativeValues':self.n.values,'nativeBytes':len(self.n.raw)}
def check_fft_reference():
 for n in [8,16]:
  data=[((i*7)%19-9)/16 for i in range(n)];ref=[sum(v*cmath.exp(-2j*math.pi*k*i/n) for i,v in enumerate(data)) for k in range(n)];got=transform(data)
  for a,b in zip(got,ref):near(a.real,b.real,8,64);near(a.imag,b.imag,8,64)
  inverse=fft(got,True)
  for a,b in zip(inverse,data):near(a.real,b,8,64);near(a.imag,0,8,64)
def source_bindings(root,mode,env,source_root):
 r=root/mode;binding=json.loads((r/'source-bindings.json').read_text());need(binding['sourceProducer']==env['candidate'] and binding['mode']==mode and binding['exactVersion']==PINS[mode]['version'],'source producer/mode/version')
 need(binding['originalFittingProducer']=='bf869284f29b7604a08d98cf66cf8a2c5619e525','immutable source baseline')
 def expected(path):
  result=subprocess.run(['git','show',env['candidate']+':'+path],cwd=source_root,capture_output=True)
  if result.returncode==0:return result.stdout
  need((source_root/path).exists(),'trusted archived source unavailable '+path);return (source_root/path).read_bytes()
 for path,digest in env['sourceHashes'].items():need(hashlib.sha256(expected(path)).hexdigest()==digest,'immutable source hash '+path)
 need(hashlib.sha256((r/'compiled-Package.swift').read_bytes()).hexdigest()==binding['manifestSHA256'],'compiled manifest')
 need(binding['traceSHA256']==env['sourceHashes']['Fixtures/AffineAdoptionBenchmark/Trace.swift'] and binding['fixtureMainSHA256']==env['sourceHashes']['Fixtures/AffineAdoptionBenchmark/Sources/AffineAdoptionBenchmark/Main.swift'] and binding['preparerSHA256']==env['sourceHashes']['Scripts/prepare-affine-adoption.py'],'trace/main/preparer source bindings')
 for path,digest in binding['compiledSourceHashes'].items():
  p=r/'compiled-Sources'/Path(path).relative_to('Sources');need(hashlib.sha256(p.read_bytes()).hexdigest()==digest,'compiled complete source hash '+path)
  if path in ['Sources/AcousticCore/RoomParameters.swift','Sources/AcousticCore/DecayAnalysis.swift']:
   name=Path(path).name;record=binding['sources'][name];data=p.read_text();need(hashlib.sha256(data.encode()).hexdigest()==record['instrumentedSHA256'],'instrumented SHA')
   for patch in reversed(record['patches']):need(data.count(patch['traced'])==1,'unique trace restoration');data=data.replace(patch['traced'],patch['original'])
   raw=data.encode();want=expected(path) if mode=='shared' else gzip.decompress(expected('Fixtures/OriginalFittingReference/'+name+'.gz'));need(raw==want and hashlib.sha256(raw).hexdigest()==record['originalSHA256'],'verbatim fitting source restoration')
  elif path=='Sources/AcousticCore/AffineTrace.swift':need(p.read_bytes()==expected('Fixtures/AffineAdoptionBenchmark/Trace.swift'),'fixture recorder body')
  elif path.startswith('Sources/AffineAdoptionBenchmark/'):need(p.read_bytes()==expected('Fixtures/AffineAdoptionBenchmark/'+path),'fixture executable body')
  else:need(p.read_bytes()==expected(path),'unchanged compiled app source '+path)
 need(set(binding['compiledSourceHashes'])=={'Sources/'+str(p.relative_to(r/'compiled-Sources')) for p in (r/'compiled-Sources').rglob('*') if p.is_file()},'complete compiled source tree')
def dependency(root,mode):
 pin=json.loads((Path(root)/mode/'consumer-Package.resolved').read_text())['pins'];need(len(pin)==1 and pin[0]['identity']=='continuumkit' and pin[0]['state']==PINS[mode],'exact public dependency')
def verify(root,source_root=None):
 check_fft_reference()
 root=Path(root);source_root=Path(source_root) if source_root else Path(__file__).resolve().parent.parent;env=json.loads((root/'environment.json').read_text());need(env['workingTreeDirty'] is False,'clean producer');results={}
 for mode in ['original','shared']:
  source_bindings(root,mode,env,source_root)
  dependency(root,mode)
  r=root/mode;report=json.loads((r/'application.json').read_text());raw=(r/'native.bin').read_bytes();
  policy=Policy(report,raw,mode)
  try:results[mode]=policy.run()
  except ValueError as error:raise ValueError(mode+' '+policy.current_case+': '+str(error)) from error
 (root/'policy-verification.json').write_text(json.dumps({'schemaVersion':1,'results':results,'scope':'independent complete native selection/noise/tail/feedback/fit policies; numerical verification, not empirical validation','fftReference':'NumPy independent complex FFT' if np is not None else 'independent scalar complex radix-two FFT'},indent=2,sort_keys=True)+'\n')
 print('PASS complete independent affine application policy references',results)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('root',type=Path);p.add_argument('--source-root',type=Path);a=p.parse_args();verify(a.root,a.source_root)
