#!/usr/bin/env python3
"""Protect the actual historical comparison and reject plausible policy corruptions."""
import subprocess, unittest, tempfile, shutil, json
from pathlib import Path
from original_spatial_reference import original_spatial_source, copy_original_spatial_reference
from spatial_query_scope import ZONE, EXPECTED, verify_spatial_query_scope, verify_spatial_query_files
ROOT = Path(__file__).resolve().parents[1]

class SpatialScopeTests(unittest.TestCase):
    def setUp(self):
        self.original = subprocess.check_output(['git', 'show', '7d73614:'+ZONE], cwd=ROOT)
        self.current = (ROOT/ZONE).read_bytes()
    def test_reviewed_scope_and_frozen_original_body(self):
        verify_spatial_query_scope(self.original, self.current)
        verify_spatial_query_files({p:(ROOT/p).read_bytes() for p in EXPECTED})
        source = self.original.decode()
        comparison = (ROOT/'Tests/AcousticCoreTests/SharedBoxQueryTests.swift').read_text()
        def body(text):
            start = text.index('        var enter = 0.0')
            end = text.index('        return enter...leave', start) + len('        return enter...leave')
            return text[start:end]
        self.assertEqual(body(source), body(comparison))
    def test_protected_compile_source_and_corruptions(self):
        self.assertEqual(original_spatial_source(ROOT, True), self.original)
        with self.assertRaises(ValueError):
            copy_original_spatial_reference(ROOT, ROOT/'Sources/AcousticCore')
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            shutil.copytree(ROOT/'Fixtures/OriginalSpatialReference', root/'Fixtures/OriginalSpatialReference')
            copy_original_spatial_reference(root, root/'consumer')
            self.assertEqual((root/'consumer/FittingZone.swift').read_bytes(),self.original)
            packed=root/'Fixtures/OriginalSpatialReference/FittingZone.swift.gz'
            packed.write_bytes(packed.read_bytes()+b'corruption')
            with self.assertRaises(ValueError): original_spatial_source(root)
            shutil.copyfile(ROOT/'Fixtures/OriginalSpatialReference/FittingZone.swift.gz',packed)
            metadata=root/'Fixtures/OriginalSpatialReference/source.json'
            data=json.loads(metadata.read_text());data['revision']='wrong';metadata.write_text(json.dumps(data))
            with self.assertRaises(ValueError): original_spatial_source(root)
    def test_contact_and_material_policy_changes_reject(self):
        for old, new in [('interval.lowerBound < interval.upperBound', 'interval.lowerBound <= interval.upperBound'),
                         ('0...limit', '0...Double.infinity'), ('4 * density', '8 * density')]:
            with self.subTest(old=old), self.assertRaises(AssertionError):
                self.assertIn(old, self.current.decode())
                verify_spatial_query_scope(self.original, self.current.decode().replace(old,new).encode())
    def test_original_and_comparison_corruptions_reject(self):
        with self.assertRaises(AssertionError):
            verify_spatial_query_scope(self.original+b'\n', self.current)
        files={p:(ROOT/p).read_bytes() for p in EXPECTED}
        for path in EXPECTED:
            with self.subTest(path=path), self.assertRaises(AssertionError):
                verify_spatial_query_files(dict(files, **{path:files[path]+b'\n'}))

if __name__ == '__main__': unittest.main()
