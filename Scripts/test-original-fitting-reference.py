#!/usr/bin/env python3
import gzip,hashlib,json,shutil,tempfile,unittest
from pathlib import Path
from original_fitting_reference import original_fitting_sources,copy_original_fitting_reference,EXPECTED
ROOT=Path(__file__).resolve().parent.parent
class FittingReference(unittest.TestCase):
 def test_exact_copy(self):
  with tempfile.TemporaryDirectory() as t:
   dest=Path(t)/'copied';copy_original_fitting_reference(ROOT,dest)
   for name,(sha,blob) in EXPECTED.items():self.assertEqual(hashlib.sha256((dest/name).read_bytes()).hexdigest(),sha)
 def test_production_copy_rejects(self):
  dest=ROOT/'Sources/AcousticCore';before={n:(dest/n).read_bytes() for n in EXPECTED}
  with self.assertRaises(ValueError):copy_original_fitting_reference(ROOT,dest)
  self.assertEqual(before,{n:(dest/n).read_bytes() for n in EXPECTED})
 def test_changed_identity_rejects(self):
  for key in ['originalPath','originalGitBlob','originalSHA256','snapshotPath']:
   with self.subTest(key=key),tempfile.TemporaryDirectory() as t:
    r=Path(t);shutil.copytree(ROOT/'Fixtures/OriginalFittingReference',r/'Fixtures/OriginalFittingReference');p=r/'Fixtures/OriginalFittingReference/source.json';m=json.loads(p.read_text());m['files']['DecayAnalysis.swift'][key]='changed';p.write_text(json.dumps(m))
    with self.assertRaises(ValueError):original_fitting_sources(r)
 def test_coherent_changed_snapshot_rejects(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);shutil.copytree(ROOT/'Fixtures/OriginalFittingReference',r/'Fixtures/OriginalFittingReference');p=r/'Fixtures/OriginalFittingReference/DecayAnalysis.swift.gz';raw=gzip.decompress(p.read_bytes());packed=gzip.compress(raw.replace(b'n * sxy',b'2 * n * sxy'));p.write_bytes(packed);m=r/'Fixtures/OriginalFittingReference/source.json';d=json.loads(m.read_text());d['files']['DecayAnalysis.swift']['snapshotSHA256']=hashlib.sha256(packed).hexdigest();m.write_text(json.dumps(d))
   with self.assertRaises(ValueError):original_fitting_sources(r)
if __name__=='__main__':unittest.main()
