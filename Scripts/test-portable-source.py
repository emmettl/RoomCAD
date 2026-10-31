#!/usr/bin/env python3
"""Reject numerical, constructor and declaration corruptions after module moves."""
import tempfile
from pathlib import Path
import shutil
import unittest
from portable_source import ROOT, reviewed_change, source_before_split


class PortableSourceTests(unittest.TestCase):
    def test_corruptions_reject(self):
        cases = [
            ('FittingZone.swift','Sources/AcousticCore/FittingZone.swift','4 * density','8 * density'),
            ('DiffuseRayTracer.swift','Sources/AcousticCore/DiffuseRayTracer.swift','self.seed = seed','self.seed = 0'),
            ('RoomParameters.swift','Sources/AcousticCore/RoomParameters.swift','Double($0 + offset)','Double($0)'),
            ('RoomResponseTypes.swift','Sources/AcousticCore/RoomResponse.swift','RoomCAD hybrid model 7','RoomCAD hybrid model 8'),
            # An original declaration beside a reviewed addition, the addition itself, and its removal.
            ('HallPiece.swift','Sources/AcousticCore/HallPiece.swift','points.count >= 3','points.count >= 2'),
            ('HallPiece.swift','Sources/AcousticCore/HallPiece.swift','points.count > 3','points.count > 2'),
            ('HallPiece.swift','Sources/AcousticCore/HallPiece.swift','/// Editing a piece in the inspector.\nextension HallPiece {','private extension Unreviewed {'),
        ]
        for name, old, before, after in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                root=Path(temporary)
                # Immutable Git objects are read through the original repository, never modified.
                (root/'.git').symlink_to(ROOT/'.git',target_is_directory=True)
                (root/'Sources/AcousticModel').mkdir(parents=True)
                (root/'Sources/AcousticCore').mkdir(parents=True)
                path=root/'Sources/AcousticModel'/name
                text=(ROOT/'Sources/AcousticModel'/name).read_text()
                self.assertIn(before,text)
                path.write_text(text.replace(before,after))
                if name=='RoomResponseTypes.swift':
                    shutil.copyfile(ROOT/'Sources/AcousticCore/RoomResponse.swift',root/'Sources/AcousticCore/RoomResponse.swift')
                with self.assertRaises(AssertionError): source_before_split(root,old)

    def test_reviewed_changes_reject(self):
        path='Sources/RoomDocument/ResponseSummary.swift'
        text=(ROOT/path).read_text()
        self.assertTrue(reviewed_change(ROOT,path))
        self.assertFalse(reviewed_change(ROOT,'Sources/RoomCAD/RoomCADApp.swift'))
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            (root/path).parent.mkdir(parents=True)
            # A comment is not a token; a changed number is.
            (root/path).write_text(text.replace('// In octaves as measured','// In octaves as acousticbench measures'))
            self.assertTrue(reviewed_change(root,path))
            # Back to the rendering bands, open below 63 Hz and above 8 kHz.
            (root/path).write_text(text.replace('measuredOctaveBand','octaveBand'))
            with self.assertRaises(AssertionError): reviewed_change(root,path)


if __name__=='__main__': unittest.main()
