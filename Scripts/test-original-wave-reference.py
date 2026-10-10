#!/usr/bin/env python3
"""Independent corruption/provenance controls for the retired numerical source."""
import hashlib
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from original_wave_reference import original_masked_source

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = Path('Fixtures/OriginalWaveReference/masked-cpu-source.json')
REFERENCE = Path('Tests/AcousticCoreTests/OriginalMaskedCPU.swift')


class OriginalReferenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        for source in (MANIFEST, REFERENCE, Path('Fixtures/OriginalWaveReference/WaveSolver.swift.gz')):
            target = self.root / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / source, target)
        for relative in ('Fixtures/WaveProductionBenchmark/Sources/WaveProductionAdapter/OriginalMaskedCPU.swift',
                         'Fixtures/ThinProbeBenchmark/Sources/ThinProbeAdapter/OriginalMaskedCPU.swift'):
            link = self.root / relative
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(self.root / REFERENCE)

    def tearDown(self):
        self.temporary.cleanup()

    def update_manifest(self, **fields):
        path = self.root / MANIFEST
        data = json.loads(path.read_text())
        data.update(fields)
        path.write_text(json.dumps(data))

    def test_complete_reconstruction_without_git(self):
        source = original_masked_source(self.root)
        self.assertIn('for (cell, w) in sourceWeights { p[cell] += Float(q) * w }', source)

    def test_changed_numerics_reject_even_with_refreshed_local_payload_hash(self):
        path = self.root / REFERENCE
        path.write_text(path.read_text().replace('Float(dt / spacing.x)', 'Float(dt / spacing.y)', 1))
        self.update_manifest(referenceSHA256=hashlib.sha256(path.read_bytes()).hexdigest())
        with self.assertRaisesRegex(ValueError, 'immutable snapshot'):
            original_masked_source(self.root)

    def test_corrupt_snapshot_rejects(self):
        path = self.root / 'Fixtures/OriginalWaveReference/WaveSolver.swift.gz'
        path.write_bytes(path.read_bytes()[:-1])
        with self.assertRaisesRegex(ValueError, 'snapshot payload changed'):
            original_masked_source(self.root)

    def test_wrong_git_blob_rejects(self):
        self.update_manifest(originalGitBlob='0' * 40)
        with self.assertRaisesRegex(ValueError, 'Git blob changed'):
            original_masked_source(self.root)

    def test_wrong_source_revision_rejects(self):
        self.update_manifest(revision='0' * 40)
        with self.assertRaisesRegex(ValueError, 'identity changed'):
            original_masked_source(self.root)

    def test_copied_or_misdirected_benchmark_control_rejects(self):
        link = self.root / 'Fixtures/ThinProbeBenchmark/Sources/ThinProbeAdapter/OriginalMaskedCPU.swift'
        link.unlink()
        shutil.copyfile(self.root / REFERENCE, link)
        with self.assertRaisesRegex(ValueError, 'canonical original reference'):
            original_masked_source(self.root)

    def test_required_git_identity_cannot_silently_fall_back(self):
        with self.assertRaisesRegex(ValueError, 'Git source unavailable'):
            original_masked_source(self.root, require_git=True)


if __name__ == '__main__':
    unittest.main()
