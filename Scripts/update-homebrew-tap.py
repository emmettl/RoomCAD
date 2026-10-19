#!/usr/bin/env python3
"""Install a verified, already-published RoomCAD archive in emmettl/tap.

Defaults to printing the proposed cask. --publish explicitly updates the tap;
this command never prepares, signs, tags or publishes an application release.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import zipfile

TAP = 'emmettl/homebrew-tap'
CASK = 'Casks/roomcad.rb'


def release_identity(version, historical=False):
    if not re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', version):
        raise ValueError('Use a numeric major.minor.patch version.')
    if historical:
        if version != '0.1.0':
            raise ValueError('Only the original 0.1.0 archive lives in BombCAD.')
        return 'emmettl/bombcad', 'roomcad-v0.1.0'
    return 'emmettl/RoomCAD', 'v'+version


def verify_archive(folder, version):
    name = f'RoomCAD-{version}-macos-arm64.zip'
    archive = folder/name
    checksum = (folder/(name+'.sha256')).read_text().strip()
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if checksum != f'{digest}  {name}':
        raise ValueError('Published checksum does not match the named archive.')
    manifest = json.loads((folder/(name.removesuffix('.zip')+'.json')).read_text())
    required = dict(version=version, bundleIdentifier='dev.roomcad.RoomCAD',
                    minimumMacOS='15.0', architecture='arm64', signing='Developer ID Application',
                    notarized=True, sha256=digest)
    if any(manifest.get(k) != v for k, v in required.items()):
        raise ValueError('Published manifest is not the expected notarized RoomCAD application.')
    with zipfile.ZipFile(archive) as zipped:
        plist = plistlib.loads(zipped.read('RoomCAD.app/Contents/Info.plist'))
    for key, value in [('CFBundleIdentifier', required['bundleIdentifier']),
                       ('CFBundleShortVersionString', version), ('LSMinimumSystemVersion', '15.0')]:
        if plist.get(key) != value:
            raise ValueError('Archive metadata disagrees with the release manifest: '+key)
    return digest


def render_cask(version, digest, historical=False):
    repo, tag = release_identity(version, historical)
    if not re.fullmatch(r'[a-f0-9]{64}', digest):
        raise ValueError('Invalid SHA-256 digest.')
    url = (f'https://github.com/{repo}/releases/download/roomcad-v#{{version}}/' if historical else
           f'https://github.com/{repo}/releases/download/v#{{version}}/')
    url += 'RoomCAD-#{version}-macos-arm64.zip'
    livecheck = ('    skip "Historical release; later releases are published in emmettl/RoomCAD"' if historical else
                 '    url :url\n    strategy :github_latest')
    return f'''cask "roomcad" do
  version "{version}"
  sha256 "{digest}"

  url "{url}"
  name "RoomCAD"
  desc "Room acoustics modelling and impulse response generation"
  homepage "https://github.com/emmettl/RoomCAD"

  livecheck do
{livecheck}
  end

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "RoomCAD.app"

  zap trash: [
    "~/Library/Caches/RoomCAD",
    "~/Library/Preferences/dev.roomcad.RoomCAD.plist",
  ]
end
'''


def gh(*args, input=None):
    return subprocess.check_output(['gh', *args], input=input, text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--historical', action='store_true', help='Use the original BombCAD 0.1.0 release')
    parser.add_argument('--publish', action='store_true', help='Commit the verified cask to emmettl/homebrew-tap')
    args = parser.parse_args()
    repo, tag = release_identity(args.version, args.historical)
    release = json.loads(gh('release', 'view', tag, '--repo', repo, '--json', 'isDraft,isPrerelease,tagName'))
    if release != dict(isDraft=False, isPrerelease=False, tagName=tag):
        raise ValueError('The cask requires an existing stable published release.')
    with tempfile.TemporaryDirectory(prefix='roomcad-tap-') as temporary:
        folder = Path(temporary)
        gh('release', 'download', tag, '--repo', repo, '--pattern', f'RoomCAD-{args.version}-macos-arm64*', '--dir', str(folder))
        digest = verify_archive(folder, args.version)
    content = render_cask(args.version, digest, args.historical)
    if not args.publish:
        print(content, end='')
        return
    # Resolve via a directory listing: absence is distinct from an authentication/network failure.
    entries = json.loads(gh('api', f'repos/{TAP}/contents/Casks'))
    entry = next((e for e in entries if e['path'] == CASK), None)
    payload = {'message': f'Add RoomCAD {args.version}' if entry is None else f'Update RoomCAD to {args.version}',
               'content': base64.b64encode(content.encode()).decode()}
    if entry:
        old = json.loads(gh('api', f'repos/{TAP}/contents/{CASK}'))
        previous = base64.b64decode(old['content']).decode()
        if previous == content:
            print('RoomCAD cask already matches the verified release.')
            return
        old_version = re.search(r'^  version "(\d+\.\d+\.\d+)"$', previous, re.M)
        if old_version is None or tuple(map(int,args.version.split('.'))) <= tuple(map(int,old_version[1].split('.'))):
            raise ValueError('Refusing to replace an equal or newer tap version with different contents.')
        payload['sha'] = old['sha']
    result = json.loads(gh('api', '--method', 'PUT', f'repos/{TAP}/contents/{CASK}', '--input', '-', input=json.dumps(payload)))
    print(result['commit']['html_url'])


if __name__ == '__main__':
    main()
