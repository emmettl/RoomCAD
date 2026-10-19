#!/usr/bin/env python3
"""Guard cask provenance, metadata and checksum verification without network writes."""
import hashlib
import json
from pathlib import Path
import plistlib
import runpy
import tempfile
import unittest
import zipfile

M = runpy.run_path(str(Path(__file__).with_name('update-homebrew-tap.py')))


class HomebrewTests(unittest.TestCase):
    def fixture(self, folder):
        name = 'RoomCAD-0.1.0-macos-arm64.zip'
        with zipfile.ZipFile(folder/name, 'w') as archive:
            archive.writestr('RoomCAD.app/Contents/Info.plist', plistlib.dumps(dict(
                CFBundleIdentifier='dev.roomcad.RoomCAD', CFBundleShortVersionString='0.1.0', LSMinimumSystemVersion='15.0')))
        digest = hashlib.sha256((folder/name).read_bytes()).hexdigest()
        (folder/(name+'.sha256')).write_text(f'{digest}  {name}\n')
        manifest = dict(version='0.1.0', bundleIdentifier='dev.roomcad.RoomCAD', minimumMacOS='15.0',
                        architecture='arm64', signing='Developer ID Application', notarized=True, sha256=digest)
        (folder/'RoomCAD-0.1.0-macos-arm64.json').write_text(json.dumps(manifest))
        return digest, manifest

    def test_published_archive_binding(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            digest, manifest = self.fixture(folder)
            self.assertEqual(M['verify_archive'](folder, '0.1.0'), digest)
            for key, value in [('notarized', False), ('sha256', '0'*64), ('bundleIdentifier', 'different'), ('version', '0.2.0')]:
                with self.subTest(key=key):
                    (folder/'RoomCAD-0.1.0-macos-arm64.json').write_text(json.dumps(dict(manifest, **{key:value})))
                    with self.assertRaises(ValueError): M['verify_archive'](folder, '0.1.0')
            self.fixture(folder)
            checksum = folder/'RoomCAD-0.1.0-macos-arm64.zip.sha256'
            checksum.write_text(checksum.read_text().replace('RoomCAD-', 'BombCAD-'))
            with self.assertRaises(ValueError): M['verify_archive'](folder, '0.1.0')
            self.fixture(folder)
            archive=folder/'RoomCAD-0.1.0-macos-arm64.zip'
            archive.write_bytes(archive.read_bytes()+b'corrupt')
            with self.assertRaises(ValueError): M['verify_archive'](folder, '0.1.0')

    def test_initial_and_future_casks(self):
        digest = '400aeb6f47a6ad1dabaecb4694f64ee4c4d33625611ea785edd766129e4be543'
        initial=M['render_cask']('0.1.0',digest,True)
        root=Path(__file__).resolve().parents[1]
        self.assertEqual(initial,(root/'Packaging/Homebrew/roomcad.rb').read_text())
        self.assertIn('bombcad/releases/download/roomcad-v#{version}', initial)
        self.assertNotIn('strategy :github_latest', initial)
        future=M['render_cask']('0.1.1',digest)
        self.assertIn('RoomCAD/releases/download/v#{version}',future)
        self.assertIn('strategy :github_latest',future)
        for version in ['../../file', '1.0', '1.0.0-beta.1', '01.0.0', '1.0.0\n']:
            with self.assertRaises(ValueError): M['release_identity'](version)
        with self.assertRaises(ValueError): M['release_identity']('0.1.1',True)
        with self.assertRaises(ValueError): M['render_cask']('0.1.0','injected')


if __name__=='__main__': unittest.main()
