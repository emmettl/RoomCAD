#!/usr/bin/env python3
"""Corruption controls for original Metal source and unchanged production layout."""
import hashlib, json, shutil, tempfile, unittest
from pathlib import Path
from original_wave_reference import original_metal_source
ROOT = Path(__file__).resolve().parent.parent
MANIFEST = Path('Fixtures/OriginalWaveReference/metal-source.json')
REF = Path('Tests/AcousticCoreTests/OriginalMetalWaveSolver.swift')

class MetalReferenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.root = Path(self.temp.name)
        for p in [MANIFEST, REF, Path('Fixtures/OriginalWaveReference/MetalWaveSolver.swift.gz'), Path('Sources/AcousticCore/WaveGridLayout.swift')]:
            q = self.root / p; q.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(ROOT / p, q)
        for package, target in [('WaveMetalProductionBenchmark','WaveMetalProductionAdapter'),('ThinProbeBenchmark','ThinProbeAdapter')]:
            q = self.root/'Fixtures'/package/'Sources'/target/'OriginalMetalWaveSolver.swift'; q.parent.mkdir(parents=True); q.symlink_to(self.root / REF)
    def tearDown(self): self.temp.cleanup()
    def update(self, **fields):
        p = self.root / MANIFEST; d = json.loads(p.read_text()); d.update(fields); p.write_text(json.dumps(d))
    def test_valid_full_original_source(self):
        self.assertIn('kernel void waveInject', original_metal_source(self.root))
    def test_changed_math_rejects_after_local_hash_refresh(self):
        p = self.root / REF; p.write_text(p.read_text().replace('p[cells[i]] += q[step] * weights[i];','p[cells[i]] -= q[step] * weights[i];'))
        self.update(referenceSHA256=hashlib.sha256(p.read_bytes()).hexdigest())
        with self.assertRaisesRegex(ValueError,'immutable source'): original_metal_source(self.root)
    def test_moved_geometry_change_rejects(self):
        p = self.root/'Sources/AcousticCore/WaveGridLayout.swift'; p.write_text(p.read_text().replace('let injection = Float(c * c * dt', 'let injection = Float(c * dt'))
        with self.assertRaisesRegex(ValueError,'grid layout'): original_metal_source(self.root)
    def test_wrong_blob_rejects(self):
        self.update(originalGitBlob='0'*40)
        with self.assertRaisesRegex(ValueError,'Git blob'): original_metal_source(self.root)
    def test_corrupt_snapshot_rejects(self):
        p=self.root/'Fixtures/OriginalWaveReference/MetalWaveSolver.swift.gz'; p.write_bytes(p.read_bytes()[:-1])
        with self.assertRaisesRegex(ValueError,'snapshot changed'): original_metal_source(self.root)
    def test_wrong_link_rejects(self):
        p=self.root/'Fixtures/ThinProbeBenchmark/Sources/ThinProbeAdapter/OriginalMetalWaveSolver.swift'; p.unlink(); shutil.copyfile(self.root/REF,p)
        with self.assertRaisesRegex(ValueError,'canonical original'): original_metal_source(self.root)
    def test_missing_required_git_rejects(self):
        with self.assertRaisesRegex(ValueError,'Git source unavailable'): original_metal_source(self.root,require_git=True)
if __name__=='__main__': unittest.main()
