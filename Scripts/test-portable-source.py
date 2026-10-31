#!/usr/bin/env python3
"""Reject numerical, constructor and declaration corruptions after module moves."""
import tempfile
from pathlib import Path
import shutil
import unittest
from portable_source import ROOT, source_before_split


class PortableSourceTests(unittest.TestCase):
    def test_corruptions_reject(self):
        cases = [
            ('FittingZone.swift','Sources/AcousticCore/FittingZone.swift','4 * density','8 * density'),
            ('DiffuseRayTracer.swift','Sources/AcousticCore/DiffuseRayTracer.swift','self.seed = seed','self.seed = 0'),
            ('RoomParameters.swift','Sources/AcousticCore/RoomParameters.swift','Double($0 + offset)','Double($0)'),
            ('RoomResponseTypes.swift','Sources/AcousticCore/RoomResponse.swift','RoomCAD hybrid model 7','RoomCAD hybrid model 8'),
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


if __name__=='__main__': unittest.main()
