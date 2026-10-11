#!/usr/bin/env python3
"""Reject unrelated model/orchestration changes even when coverage text is plausible."""
import subprocess,unittest
from pathlib import Path
from calibration_reporting_scope import OLD,NEW,verify_reporting_scope
from verified_calibration_scope import NEW_SOURCE,EXPECTED,verify_verified_calibration_scope
ROOT=Path(__file__).resolve().parents[1]
class ScopeTests(unittest.TestCase):
    def setUp(self):
        self.original=subprocess.check_output(['git','show','bf869284f29b7604a08d98cf66cf8a2c5619e525:Sources/RoomCAD/CalibrationSection.swift'],cwd=ROOT)
        self.updated=self.original.decode().replace(OLD,NEW).encode()
    def test_exact_change_and_frozen_original(self):
        verify_reporting_scope(self.original,self.original)
        verify_reporting_scope(self.original,self.updated)
        if (ROOT/NEW_SOURCE).exists():
            verify_verified_calibration_scope({p:(ROOT/p).read_bytes() for p in EXPECTED})
        else:self.assertEqual((ROOT/'Sources/RoomCAD/CalibrationSection.swift').read_bytes(),self.updated)
    def test_unrelated_calibration_or_simulation_changes_reject(self):
        for before,after in [('to: target)','to: target.map { $0.map { $0 * 2 } })'),('quality: .preview','quality: .full'),('reports.count += 1','reports.count += 2')]:
            with self.subTest(before=before),self.assertRaises(AssertionError):
                text=self.updated.decode();self.assertIn(before,text);verify_reporting_scope(self.original,text.replace(before,after).encode())
    def test_missing_coverage_branch_and_changed_claim_reject(self):
        for before,after in [('errors.count < used.count','errors.count > used.count'),('targeted bands','all targets'),('unavailable','available')]:
            with self.subTest(before=before),self.assertRaises(AssertionError):verify_reporting_scope(self.original,self.updated.decode().replace(before,after).encode())
if __name__=='__main__':unittest.main()
