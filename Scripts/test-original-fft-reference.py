#!/usr/bin/env python3
import gzip,hashlib,json,shutil,tempfile,unittest
from pathlib import Path
from original_fft_reference import original_fft_source,copy_original_fft_reference
ROOT=Path(__file__).resolve().parent.parent
class FFTReference(unittest.TestCase):
 def test_exact_copy(self):
  with tempfile.TemporaryDirectory() as t:
   dest=Path(t)/'copied';copy_original_fft_reference(ROOT,dest)
   self.assertEqual(hashlib.sha256((dest/'RealFFT.swift').read_bytes()).hexdigest(),'63da5cb9c3ead610051a2b43faf3c345d4168d7e6580abd25ea202c18877b617')
 def test_production_copy_rejects(self):
  p=ROOT/'Sources/AcousticCore/RealFFT.swift';before=p.read_bytes()
  with self.assertRaises(ValueError):copy_original_fft_reference(ROOT,p.parent)
  self.assertEqual(p.read_bytes(),before)
 def test_changed_identity_rejects(self):
  for key in ['revision','originalPath','originalGitBlob','originalSHA256','snapshotPath']:
   with self.subTest(key=key),tempfile.TemporaryDirectory() as t:
    r=Path(t);shutil.copytree(ROOT/'Fixtures/OriginalFFTReference',r/'Fixtures/OriginalFFTReference');p=r/'Fixtures/OriginalFFTReference/source.json';m=json.loads(p.read_text());m[key]='changed';p.write_text(json.dumps(m))
    with self.assertRaises(ValueError):original_fft_source(r)
 def test_changed_snapshot_rejects_even_with_new_compressed_hash(self):
  with tempfile.TemporaryDirectory() as t:
   r=Path(t);shutil.copytree(ROOT/'Fixtures/OriginalFFTReference',r/'Fixtures/OriginalFFTReference');p=r/'Fixtures/OriginalFFTReference/RealFFT.swift.gz';raw=gzip.decompress(p.read_bytes());packed=gzip.compress(raw.replace(b'2 * length',b'4 * length'));p.write_bytes(packed);m=r/'Fixtures/OriginalFFTReference/source.json';d=json.loads(m.read_text());d['snapshotSHA256']=hashlib.sha256(packed).hexdigest();m.write_text(json.dumps(d))
   with self.assertRaises(ValueError):original_fft_source(r)
if __name__=='__main__':unittest.main()
