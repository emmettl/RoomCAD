#!/usr/bin/env python3
"""Require complete, strictly conforming plan/mesh pulse histories and independent wall identities."""
import argparse,json,math
from pathlib import Path

def read(path):
    return json.loads(path.read_text())

def geometry(audit,record,representation):
    h=record['history'];r=record['resolution'];nx,ny,nz=[r[k] for k in ('nx','ny','nz')]
    count=nx*ny*nz;d=h['fields']['spacing']
    assert audit['caseID']==record['specification']['id'] and audit['representation']==representation
    assert audit['resolution']==r and audit['inside']==h['inside'] and audit['spacing']==d
    assert audit['layoutFaces']==h['layoutFaces'] and audit['layoutDt']==h['layoutDt']
    assert audit['unresolvedCrossings']==[]
    ids=audit['selectedFaces'];normals=audit['normalSampleFaces'];faces=audit['layoutFaces']
    assert len(ids)==len(normals)==len(faces)==6*count
    # Independent outward convex planes, in physical wall order, including rigid caps.
    # Their directed intersection establishes material identity; no app query is used.
    planes=[([0,-1,0],0),([1,.5,0],.45),([0,1,0],.5),([-1,0,0],0),([0,0,-1],0),([0,0,1],.00390625)]
    closed=0
    for index,value in enumerate(faces):
        if value<0:
            assert value==-1 and ids[index]==normals[index]==-1
            continue
        side=index//count;cell=index%count;axis=side//2;sign=-1 if side%2==0 else 1
        point=[(cell%nx+.5)*d[0],(cell//nx%ny+.5)*d[1],(cell//(nx*ny)+.5)*d[2]]
        exits=[]
        for face,(n,b) in enumerate(planes):
            denom=n[axis]*sign*d[axis]
            if denom>0:
                t=(b-sum(x*y for x,y in zip(n,point)))/denom
                if 0<t<=1+1e-9:exits.append((t,face))
        assert exits,'Closed face has no independent physical exit'
        expected=min(exits)[1]
        assert ids[index]==expected,(representation,r['axis'],nx,index,ids[index],expected)
        # Every declared wall is planar. Its in-plane nearest normal must be the same plane.
        assert normals[index]==expected,(representation,'normal',nx,index,normals[index],expected)
        closed+=1
    return closed

def check(root):
    summaries=[];environments=[]
    for backend in ('cpu','metal'):
        paths={'plan':root/backend,'mesh':root/'mesh'/backend}
        runs={};audits={}
        for representation,path in paths.items():
            records=read(path/'results.json');env=read(path/'environment.json');audit=read(path/'geometry.json')
            reports=read(path/'conformance.json')
            assert len(records)==len(audit)==6 and len(reports)==2
            assert env['workingTreeDirty'] is False
            assert all(row['status']=='passed' for row in reports),'Spatial/time gap is not paired conformance'
            model='RoomCAD.'+backend+'.'+('tilted-pulse' if representation=='plan' else 'tilted-mesh-pulse')
            for r,g in zip(records,audit):
                assert r['status']=='supported' and r['model']==model and r['environment']==env
                assert all(math.isfinite(x) for x in r['errors']['fieldL2'])
                geometry(g,r,representation)
            runs[representation]=records;audits[representation]=audit;environments.append(env)
        assert runs['plan'][0]['environment']==runs['mesh'][0]['environment']
        for i,(plan,mesh) in enumerate(zip(runs['plan'],runs['mesh'])):
            for key in ('specification','resolution','reference','history','errors'):
                assert plan[key]==mesh[key],(backend,i,key,'Plan/mesh numerical mismatch')
            # Same complete mask, unscaled coefficients, material identities, normal samples and clock.
            for key in ('inside','layoutFaces','spacing','layoutDt','selectedFaces','normalSampleFaces','unresolvedCrossings'):
                assert audits['plan'][i][key]==audits['mesh'][i][key],(backend,i,key)
            e=mesh['errors']
            summaries.append(dict(backend=backend,resolution=mesh['resolution'],exactPlanHistory=True,
                exactPlanErrors=True,exactPlanLayout=True,unresolvedCrossings=0,
                fieldL2=e['fieldL2'],energyBudget=e['energyBudget'],patchWorkError=e['patchWorkError'],
                reflectedCoefficient=e['reflectedCoefficient'],continuumCoefficient=e['continuumCoefficient'],
                pulseShift=e['pulseShift']))
    assert all(e==environments[0] for e in environments)
    result=dict(schemaVersion=1,scope='one z-invariant xi3 tilted thin extrusion',records=24,
                pairedHistories=12,exactPlanMeshHistories=12,results=summaries)
    (root/'pair-comparison.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    print('PASS 24 strict source pulse histories; 12 exact plan/mesh pairs; independent wall identities and zero fallback')
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path);a=p.parse_args();check(a.output)
