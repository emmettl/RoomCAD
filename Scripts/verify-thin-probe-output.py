#!/usr/bin/env python3
"""Independent minimal-grid addresses and two-step source/velocity timing oracle."""
import argparse,json,math,struct
from pathlib import Path
STEPS={0,1,2,63,64,65,127,128,129,257}
SHARES=[1,0.7,0.5,0.37,0.25,0]
def require(value,label):
    if not value:raise ValueError(label)
def f32(value):return struct.unpack('>f',struct.pack('>f',value))[0]
def bits(value):
    require(math.isfinite(value),'nonfinite signal')
    return int.from_bytes(struct.pack('>d',value),'big')
def verify(root):
    env=json.loads((root/'environment.json').read_text());require(env['workingTreeDirty'] is False,'dirty producer')
    report=json.loads((root/'thin-probes.json').read_text());require(report['candidate']==env['revision'] and report['device'],'producer/device scope')
    pins=json.loads((root/'consumer-Package.resolved').read_text())['pins'];require(len(pins)==1 and pins[0]['identity']=='continuumkit' and pins[0]['state']=={'version':'0.1.0-alpha.10','revision':'da7cb5f5ac642edc57e8433c6150dceca6b9edd9'},'exact dependency')
    scenes=report['scenes'];require(len(scenes)==9 and {(s['axis'],s['representation']) for s in scenes}=={(a,r) for a in range(3) for r in ('box','plan','mesh')},'complete scene tree')
    total=0
    for scene in scenes:
        axis=scene['axis'];d=scene['dimensions'];require(d==[2 if i==axis else 4 for i in range(3)],'minimal grid')
        count=math.prod(d);require(len(scene['inside'])==count and all(v==1 for v in scene['inside']) and len(scene['faces'])==6*count,'complete layout')
        require(scene['probeCell']==[1,1,1],'declared cell rule')
        at=1+d[0]*(1+d[1]);require(scene['velocityCells']==[at]*6,'flattened addresses')
        require(at%d[0]>0 and at//d[0]%d[1]>0 and at//(d[0]*d[1])>0,'negative faces in same valid row/plane')
        require(len(scene['pressureCells'])==len(scene['pressureWeights'])==48 and len(scene['axes'])==18,'complete receiver mapping')
        require(len(scene['sourceCells'])==len(scene['sourceWeights'])==8,'complete source mapping')
        require(len(scene['runs'])==10 and {r['steps'] for r in scene['runs']}==STEPS,'complete boundary histories')
        for run in scene['runs']:
            for backend in ('cpu','shared','metal'):
                values=run[backend];encoded=run[backend+'Bits'];require(len(values)==len(encoded)==6,'all microphone patterns')
                require(all(len(v)==len(b)==run['steps'] for v,b in zip(values,encoded)),'complete streams')
                require(all(bits(v)==b for row,raw in zip(values,encoded) for v,b in zip(row,raw)),'complete bit representation')
            require(run['cpuBits']==run['sharedBits'],'same CPU arithmetic')
            total+=6*run['steps']
        c=scene['speed'];dt=scene['timeStep'];h=scene['spacing'][axis];volume=math.prod(scene['spacing'])
        require(volume==scene['volume'] and dt>0,'physical input scope')
        frequency=c/10*(1-1e-9);sigma=1.517/(math.pi*frequency*1.5)
        x=(0.5*dt-4*sigma)/sigma;q=-x*math.exp(-x*x)
        initial_box=f32(c*c*dt*q/volume)
        initial_masked=f32(f32(q)*f32(c*c*dt/volume))
        cpu_initial=initial_box if scene['representation']=='box' else initial_masked
        two=next(r for r in scene['runs'] if r['steps']==2)
        for backend,initial in [('cpu',cpu_initial),('shared',cpu_initial),('metal',initial_masked)]:
            face=f32(f32(dt/h)*initial);pressure=f32(f32(c*c*dt/h)*face)
            for receiver,a in enumerate(SHARES):
                # V1=0, V2=face/2. First sample uses (V1+V2)/2; terminal uses V2.
                expected=[-(1-a)*c*(face/4),a*pressure-(1-a)*c*(face/2)]
                for actual,wanted in zip(two[backend][receiver],expected):
                    require(abs(actual-wanted)<=1e-6*max(abs(wanted),1e-15),'independent two-step pressure/velocity clock oracle')
        one=next(r for r in scene['runs'] if r['steps']==1)
        require(all(v[0]==0 for backend in ('cpu','shared','metal') for v in one[backend]),'single-step final half-time oracle')
    require(total==45144,'complete sample count')
    return {'schemaVersion':1,'status':'passed','candidate':env['revision'],'scenes':9,'completeRuns':90,'samplesPerBackend':total,'cpuBitMismatches':0,'actualMetal':'required; no fallback','oracle':'independent two-step pulse/field/time alignment on every axis/representation/pattern','scope':'safe sampling policy/numerical conformance; no physical room accuracy claim'}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('root',type=Path);a=p.parse_args();r=verify(a.root)
    (a.root/'verification.json').write_text(json.dumps(r,indent=2,sort_keys=True)+'\n');print('PASS nine minimal-grid scenes, 90 complete CPU/shared/actual-Metal runs;',r['samplesPerBackend'],'samples per backend and independent timing oracle')
