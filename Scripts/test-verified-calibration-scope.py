#!/usr/bin/env python3
"""Exact source controls for the separately verified calibration policy and callers."""
import unittest
from pathlib import Path
from verified_calibration_scope import EXPECTED, verify_verified_calibration_scope

ROOT = Path(__file__).resolve().parents[1]

class ScopeTests(unittest.TestCase):
    def setUp(self):
        self.files = {p: (ROOT/p).read_bytes() for p in EXPECTED}

    def test_reviewed_sources(self):
        verify_verified_calibration_scope(self.files)

    def test_policy_and_caller_changes_reject(self):
        controls = {
            'Sources/AcousticCore/ValidatedAbsorptionCalibration.swift': [
                ('finalSettings.room = selected.room', 'finalSettings.room = settings.room'),
                ('let channels = try simulate(finalSettings)', 'let channels: [[Float]] = []'),
                ('time.isFinite, time > 0', 'time.isFinite, time >= 0'),
                ('matchedBandCount == targetedBandCount', 'matchedBandCount <= targetedBandCount'),
                ('TargetMeasurement.assess(time: times[band]', 'TargetMeasurement.assess(time: selected.best.reverberationTime[band]'),
            ],
            'Sources/RoomCAD/CalibrationSection.swift': [
                ('quality: .preview', 'quality: .full'),
                ('Self.validatedSummary(outcome)', 'Self.summary(outcome.selectedBest, simulations: outcome.simulationCount, target: target)'),
                ('apply(outcome.room)', 'apply(settings.room)'),
            ],
            'Sources/acousticbench/MeasuredRoom.swift': [
                ('AbsorptionCalibration.fitValidated(probe', 'AbsorptionCalibration.fitValidated(withZones.settings(set: "refitted", source: "LS1", driver: 1, receivers: [], duration: 3.5)'),
                ('outcome.verification', 'Optional(outcome.selectedBest)'),
            ],
        }
        for path, substitutions in controls.items():
            for before, after in substitutions:
                with self.subTest(path=path, before=before):
                    source = self.files[path].decode()
                    self.assertIn(before, source)
                    changed = dict(self.files)
                    changed[path] = source.replace(before, after).encode()
                    with self.assertRaises(AssertionError):
                        verify_verified_calibration_scope(changed)

    def test_missing_sources_reject(self):
        for path in self.files:
            with self.subTest(path=path), self.assertRaises(AssertionError):
                verify_verified_calibration_scope({p:b for p,b in self.files.items() if p != path})

if __name__ == '__main__':
    unittest.main()
