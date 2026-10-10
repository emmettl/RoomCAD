"""Reconstruct and verify the immutable original masked CPU control."""
import gzip
import hashlib
import json
import subprocess
from pathlib import Path

REVISION = 'c47fdc889ef294571fa5683963e5892afe5e38ab'
SELECTOR = 'extension WaveSolver {\n    /// The same scheme for a room with a floor plan or a mesh:'


def original_masked_source(root: Path, require_git: bool = False) -> str:
    manifest = json.loads((root / 'Fixtures/OriginalWaveReference/masked-cpu-source.json').read_text())
    if manifest['revision'] != REVISION or manifest['originalPath'] != 'Sources/AcousticCore/WaveSolver.swift':
        raise ValueError('Original reference identity changed')
    snapshot = (root / manifest['snapshotPath']).read_bytes()
    if hashlib.sha256(snapshot).hexdigest() != manifest['snapshotSHA256']:
        raise ValueError('Original snapshot payload changed')
    original = gzip.decompress(snapshot)
    blob = hashlib.sha1(b'blob ' + str(len(original)).encode() + b'\0' + original).hexdigest()
    if (len(original) != manifest['originalBytes'] or blob != manifest['originalGitBlob']
            or hashlib.sha256(original).hexdigest() != manifest['originalSHA256']):
        raise ValueError('Original snapshot Git blob changed')
    result = subprocess.run(['git', 'show', REVISION + ':' + manifest['originalPath']],
                            cwd=root, capture_output=True)
    if result.returncode == 0:
        if result.stdout != original:
            raise ValueError('Snapshot differs from immutable Git source')
    elif require_git:
        raise ValueError('Original Git source unavailable; fetch original revision ' + REVISION)
    source = (root / manifest['referencePath']).read_bytes()
    if hashlib.sha256(source).hexdigest() != manifest['referenceSHA256']:
        raise ValueError('Verification reference payload changed')
    text = source.decode()
    original_text = original.decode()
    expected = original_text[original_text.index(SELECTOR):]
    actual = text[text.index(SELECTOR):text.index('\n/// Verification-only original control;')]
    if actual != expected or hashlib.sha256(actual.encode()).hexdigest() != manifest['verbatimExtensionSHA256']:
        raise ValueError('Original numerical method differs from immutable snapshot')
    for package, target in [('WaveProductionBenchmark', 'WaveProductionAdapter'), ('ThinProbeBenchmark', 'ThinProbeAdapter')]:
        link = root / 'Fixtures' / package / 'Sources' / target / 'OriginalMaskedCPU.swift'
        if not link.is_symlink() or link.resolve() != (root / manifest['referencePath']).resolve():
            raise ValueError('Benchmark does not reuse the canonical original reference')
    return text


def copy_original_masked_reference(root: Path, destination: Path) -> None:
    # Frozen geometry consumers compile AcousticCore without the app build setting.
    # Their control lives in that copied module, so omit only its self-module import.
    text = original_masked_source(root)
    text = text.replace('@testable import AcousticCore\n', '')
    (destination / 'OriginalMaskedCPU.swift').write_text(text)
    metal = original_metal_source(root, reference=True)
    (destination / 'OriginalMetalWaveSolver.swift').write_text(metal.replace('@testable import AcousticCore\n', ''))


def original_metal_source(root: Path, require_git: bool = False, reference: bool = False) -> str:
    manifest = json.loads((root / 'Fixtures/OriginalWaveReference/metal-source.json').read_text())
    if manifest['revision'] != REVISION or manifest['originalPath'] != 'Sources/AcousticCore/MetalWaveSolver.swift':
        raise ValueError('Original Metal identity changed')
    compressed = (root / manifest['snapshotPath']).read_bytes()
    if hashlib.sha256(compressed).hexdigest() != manifest['snapshotSHA256']:
        raise ValueError('Original Metal snapshot changed')
    original = gzip.decompress(compressed)
    blob = hashlib.sha1(b'blob ' + str(len(original)).encode() + b'\0' + original).hexdigest()
    if blob != manifest['originalGitBlob'] or hashlib.sha256(original).hexdigest() != manifest['originalSHA256']:
        raise ValueError('Original Metal Git blob changed')
    git = subprocess.run(['git', 'show', REVISION + ':' + manifest['originalPath']], cwd=root, capture_output=True)
    if git.returncode == 0:
        if git.stdout != original: raise ValueError('Original Metal snapshot differs from Git source')
    elif require_git:
        raise ValueError('Original Metal Git source unavailable')
    canonical = (root / manifest['referencePath']).read_bytes()
    if hashlib.sha256(canonical).hexdigest() != manifest['referenceSHA256']:
        raise ValueError('Original Metal reference payload changed')
    text = canonical.decode()
    expected = original.decode()
    start = expected.index('/// The wave solver')
    end = expected.index('\nextension WaveSolver {')
    actual = text[text.index('/// The wave solver'):text.index('\n// Verification-only original selection;')]
    if actual != expected[start:end] or hashlib.sha256(actual.encode()).hexdigest() != manifest['verbatimClassSHA256']:
        raise ValueError('Original Metal implementation differs from immutable source')
    layout = (root / 'Sources/AcousticCore/WaveGridLayout.swift').read_text()
    if layout[layout.index('extension WaveSolver {'):] != expected[end + 1:]:
        raise ValueError('Moved grid layout differs from original source')
    for package, target in [('WaveMetalProductionBenchmark', 'WaveMetalProductionAdapter'), ('ThinProbeBenchmark', 'ThinProbeAdapter')]:
        link = root / 'Fixtures' / package / 'Sources' / target / 'OriginalMetalWaveSolver.swift'
        if not link.is_symlink() or link.resolve() != (root / manifest['referencePath']).resolve():
            raise ValueError('Benchmark does not reuse canonical original Metal source')
    return text if reference else expected
