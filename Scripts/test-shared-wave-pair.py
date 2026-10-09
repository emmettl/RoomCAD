#!/usr/bin/env python3
"""Independent schema controls: whole-field/clock/layout corruption cannot hide behind equal metrics."""
import copy,json,subprocess,tempfile,unittest
from pathlib import Path
root=Path(__file__).resolve().parents[1]
class PairControls(unittest.TestCase):
 def invoke(self,change=None):
  with tempfile.TemporaryDirectory() as temporary:
   folder=Path(temporary)
   for backend in ['cpu','metal']:
    original=folder/'original/masked'/backend;shared=folder/'shared/masked'/backend
    original.mkdir(parents=True);shared.mkdir(parents=True)
    oldenv={'workingTreeDirty':False,'sourceHashes':{'Sources/AcousticCore/control.swift':'0'*64},'dependencies':{'continuumkit':'original-control'}}
    newenv=copy.deepcopy(oldenv);newenv['dependencies']['continuumkit']='shared-control'
    records=[{'schemaVersion':1,'status':'supported','model':'RoomCAD.'+backend+'.control','specification':{'id':'hand-schema-control-'+str(i)},'resolution':{'axis':'time','nx':2,'ny':2,'nz':2,'steps':1},'reference':'hand-schema-control','history':{'fields':{'frames':[{'step':0,'p':[1,0],'u':[0,0],'v':[0,0],'w':[0,0]}]},'inside':[1,1],'faces':[0,0]},'errors':{'fieldL2':[0,0,0,0]},'environment':oldenv,'runtime':0} for i in range(12)]
    candidates=copy.deepcopy(records)
    for r in candidates:r['model']=r['model'].replace('RoomCAD.','RoomCAD.shared.',1);r['environment']=newenv
    provenance={'originalReferenceRevision':'original-control','sharedImplementationRevision':'shared-control','referenceSourceHashes':{'control.swift':'0'*64}}
    if backend=='cpu' and change:change(candidates,provenance)
    for directory,env,data in [(original,oldenv,records),(shared,newenv,candidates)]:
     (directory/'environment.json').write_text(json.dumps(env));(directory/'results.json').write_text(json.dumps(data))
    (shared/'reference-provenance.json').write_text(json.dumps(provenance));(shared/'conformance.json').write_text('[{"status":"passed"}]')
   result=subprocess.run(['python3',str(root/'Scripts/verify-shared-wave-pair.py'),str(folder/'original'),str(folder/'shared'),'--output',str(folder/'proof.json'),'--suites','masked'],capture_output=True,text=True)
   return result.returncode,(folder/'proof.json').exists()
 def test_matching_complete_schema_passes(self):self.assertEqual(self.invoke(),(0,True))
 def reject(self,change):
  code,proof=self.invoke(change);self.assertNotEqual(code,0);self.assertFalse(proof)
 def test_pressure_corruption_with_unchanged_errors_fails(self):
  self.reject(lambda r,p:r[0]['history']['fields']['frames'][0]['p'].__setitem__(0,2))
 def test_wrong_clock_fails(self):
  self.reject(lambda r,p:r[0]['history']['fields']['frames'][0].__setitem__('step',1))
 def test_wrong_layout_fails(self):
  self.reject(lambda r,p:r[0]['history']['inside'].__setitem__(0,0))
 def test_missing_velocity_fails(self):
  self.reject(lambda r,p:r[0]['history']['fields']['frames'][0].__setitem__('w',[]))
 def test_wrong_reference_pin_fails(self):
  self.reject(lambda r,p:p.__setitem__('originalReferenceRevision','unverified'))
if __name__=='__main__':unittest.main()
