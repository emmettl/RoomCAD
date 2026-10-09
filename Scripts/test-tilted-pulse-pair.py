#!/usr/bin/env python3
"""Hand-derived material-plane identities and rejection controls for the pulse pair audit."""
import importlib.util,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location("pulse_pair",Path(__file__).with_name("verify-tilted-pulse-pair.py"))
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
geometry=module.geometry

class DirectedPlanes(unittest.TestCase):
    def setUp(self):
        ids=[3,-1,3,-1,3,-1,3,-1]+[-1,1,1,-1,-1,1,1,-1]+[0,0,-1,-1,0,0,-1,-1]+[-1,1,2,-1,-1,1,2,-1]+[4,4,4,-1,-1,-1,-1,-1]+[-1,-1,-1,-1,5,5,5,-1]
        faces=[-1 if i<0 else (1 if i==1 else 0) for i in ids]
        resolution=dict(axis='space',nx=2,ny=2,nz=2,steps=1)
        spacing=[.25,.25,.001953125];inside=[1,1,1,0,1,1,1,0]
        self.record=dict(specification=dict(id='manual-six-cell-trapezoid'),resolution=resolution,
                         history=dict(inside=inside,layoutFaces=faces,layoutDt=1e-6,fields=dict(spacing=spacing)))
        self.audit=dict(caseID='manual-six-cell-trapezoid',representation='mesh',resolution=resolution,
                        inside=inside,layoutFaces=faces,layoutDt=1e-6,spacing=spacing,
                        selectedFaces=ids,normalSampleFaces=list(ids),unresolvedCrossings=[])
    def test_hand_counted_exits(self):
        self.assertEqual(geometry(self.audit,self.record,'mesh'),22)
    def test_cap_cannot_replace_side_material(self):
        self.audit['selectedFaces'][9]=4
        with self.assertRaises(AssertionError):geometry(self.audit,self.record,'mesh')
    def test_wrong_normal_rejected(self):
        self.audit['normalSampleFaces'][9]=4
        with self.assertRaises(AssertionError):geometry(self.audit,self.record,'mesh')
    def test_unresolved_query_rejected(self):
        self.audit['unresolvedCrossings']=[9]
        with self.assertRaises(AssertionError):geometry(self.audit,self.record,'mesh')
    def test_unknown_implementation_rejected_before_reading_reports(self):
        with self.assertRaises(AssertionError):module.check(Path('/missing'),model_prefix='unknown')
    def test_missing_identity_rejected(self):
        self.audit['selectedFaces']=self.audit['selectedFaces'][:-1]
        with self.assertRaises(AssertionError):geometry(self.audit,self.record,'mesh')

if __name__=='__main__':unittest.main()
