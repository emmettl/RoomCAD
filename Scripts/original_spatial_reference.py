"""Protected application-only compile source for pre-Double-query consumers."""
import gzip, hashlib, json, subprocess
from pathlib import Path
EXPECTED = {'schemaVersion': 1, 'repository': 'https://github.com/emmettl/RoomCAD', 'revision': '7d73614f146799c11313aacc0ccc30d44906edfc', 'originalPath': 'Sources/AcousticCore/FittingZone.swift', 'snapshotPath': 'Fixtures/OriginalSpatialReference/FittingZone.swift.gz', 'originalBytes': 7872, 'originalSHA256': '16a7ba8f2610b707bfa24fbbeec914ad34b2910fbdfb8dbdf08390982db219f6', 'originalGitBlob': '0e4bdbca84a950092ee86c060dbdb63863c544c4', 'snapshotSHA256': '9048efc087b78288779cfb5ec2a8eb2dfd49a53a7d4af01f649b4911634e1fd1', 'license': 'MIT'}

def original_spatial_source(root: Path, require_git: bool = False) -> bytes:
    metadata=json.loads((root/'Fixtures/OriginalSpatialReference/source.json').read_text())
    if metadata != EXPECTED: raise ValueError('Original spatial provenance changed')
    packed=(root/metadata['snapshotPath']).read_bytes()
    if hashlib.sha256(packed).hexdigest()!=metadata['snapshotSHA256']: raise ValueError('Original spatial snapshot changed')
    raw=gzip.decompress(packed)
    if len(raw)!=metadata['originalBytes'] or hashlib.sha256(raw).hexdigest()!=metadata['originalSHA256'] or hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()!=metadata['originalGitBlob']:
        raise ValueError('Original spatial source changed')
    git=subprocess.run(['git','show',metadata['revision']+':'+metadata['originalPath']],cwd=root,capture_output=True)
    if git.returncode==0 and git.stdout!=raw: raise ValueError('Original spatial Git source differs')
    if require_git and git.returncode!=0: raise ValueError('Original spatial Git source unavailable')
    return raw

def copy_original_spatial_reference(root: Path, destination: Path) -> None:
    if destination.resolve().is_relative_to((root/'Sources').resolve()):
        raise ValueError('Verification spatial source must never be copied into production')
    raw=original_spatial_source(root)
    destination.mkdir(parents=True,exist_ok=True)
    (destination/'FittingZone.swift').write_bytes(raw)
