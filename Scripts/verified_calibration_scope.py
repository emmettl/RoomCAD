"""Exact reviewed verified-outcome sources; all historical numeric guards still apply.

These identities permit only the separately reviewed new API and its two callers.
Any later policy edit must establish its own bounded verification checkpoint.
"""
import hashlib

EXPECTED = {'Sources/AcousticCore/ValidatedAbsorptionCalibration.swift': '1f35132ea65f0518bbb61ecdc563306d11c2e3057704313ac8514f23721a0705', 'Sources/RoomCAD/CalibrationSection.swift': '1833df5dd20c75ef2a0b17751e34e318e2a401ad570c7545dabb0b1ca1cb8162', 'Sources/acousticbench/MeasuredRoom.swift': '4d2f59d0aa95b70afaf4d425afe35c0afdf5e49433610cd3157cd6e7d6d897e8'}
NEW_SOURCE = 'Sources/AcousticCore/ValidatedAbsorptionCalibration.swift'

def verify_verified_calibration_scope(files):
    for path, expected in EXPECTED.items():
        assert path in files, 'missing verified calibration source: '+path
        assert hashlib.sha256(files[path]).hexdigest()==expected, 'verified calibration source changed: '+path
