#!/usr/bin/env python3
"""Require complete current-app masked CPU parity and separately labelled timing evidence."""
import argparse, json, math, struct
from pathlib import Path

CASES = {'rigid-plan', 'lossy-open-plan', 'masked-L', 'tilted-plan', 'tilted-mesh', 'thin-plan', 'padded-inactive', 'padded-nearest'}
STEPS = {0, 1, 63, 64, 65, 127, 128, 129, 257}
VERSION = '0.1.0-alpha.12'
CORE = 'f464e04866903bfc7c9ce94c34d31125a776d270'
# The alpha.17 migration keeps every pre-existing CAD/response/wave source byte.
# Retain exact alpha.12 histories and reject every other version/revision pair.
DEPENDENCIES = {VERSION: CORE, '0.1.0-alpha.17': 'e94d329c55495ca561306174d624eadf5c8e7da0'}

def require(condition, message):
    if not condition: raise ValueError(message)

def bits(value, width):
    require(isinstance(value, (int, float)) and math.isfinite(value), 'nonfinite sample')
    return int.from_bytes(struct.pack('>d' if width == 64 else '>f', value), 'big')

def compare_channels(record, receivers, frames, width):
    for name in ('original', 'shared', 'applicationDefault'):
        values, encoded = record[name], record[name + 'Bits']
        require(len(values) == len(encoded) == receivers, 'channel count')
        require(all(len(v) == len(b) == frames for v, b in zip(values, encoded)), 'complete channel history')
        require(all(bits(v, width) == b for channel, raw in zip(values, encoded) for v, b in zip(channel, raw)), 'sample/bit representation')
    require(record['originalBits'] == record['sharedBits'] == record['applicationDefaultBits'], 'whole output bit mismatch')

def verify(root):
    environment = json.loads((root / 'environment.json').read_text())
    require(environment['workingTreeDirty'] is False, 'dirty producer')
    require(len(environment['revision']) == 40 and all(c in '0123456789abcdef' for c in environment['revision']), 'producer revision')
    dependency = environment['dependency']
    require(dependency.get('version') in DEPENDENCIES and dependency == {'version': dependency['version'], 'revision': DEPENDENCIES[dependency['version']]}, 'exact dependency envelope')
    resolved = json.loads((root / 'consumer-Package.resolved').read_text())
    pins = [p for p in resolved['pins'] if p['identity'] == 'continuumkit']
    require(len(pins) == 1 and pins[0]['state'] == environment['dependency'], 'exact resolved dependency')
    report = json.loads((root / 'cpu-production.json').read_text())
    require(report['schemaVersion'] == 1 and report['backend'] == 'cpu' and report['candidate'] == environment['revision'], 'report scope/revision')
    require(len(report['cases']) == len(CASES) and {c['id'] for c in report['cases']} == CASES, 'complete case tree')
    total = 0
    for case in report['cases']:
        dims = case['dimensions']
        require(len(dims) == 3 and all(isinstance(d, int) and d >= 2 for d in dims), 'dimensions')
        count = math.prod(dims); receivers = len(case['receivers'])
        speed = 331.3 * math.sqrt((case['atmosphere']['temperatureCelsius'] + 273.15) / 273.15)
        sizes = case['room']['size']
        expected_dims = [max(2, math.ceil(size / (speed / (case['topFrequency'] * 10)))) for size in sizes]
        require(dims == expected_dims, 'actual solver grid preparation')
        expected_spacing = [size / n for size, n in zip(sizes, dims)]
        require(case['spacing'] == expected_spacing, 'actual grid spacing')
        limit = 0.95 / (speed * math.sqrt(sum(1 / (d * d) for d in expected_spacing)))
        decimation = 1
        while 2 * decimation / case['sampleRate'] <= limit: decimation *= 2
        require(case['timeStep'] == decimation / case['sampleRate'], 'actual solver pressure clock')
        require(receivers == (2 if case['id'] == 'thin-plan' else 6), 'microphone coverage')
        require(len(case['inside']) == count and set(case['inside']) <= {0, 1} and 1 in case['inside'], 'complete mask')
        require(len(case['faces']) == 6 * count and all(math.isfinite(v) for v in case['faces']), 'complete face coefficients')
        require(len(case['spacing']) == 3 and all(v > 0 and math.isfinite(v) for v in case['spacing']), 'spacing')
        require(case['timeStep'] > 0 and math.isfinite(case['timeStep']), 'clock')
        require(len(case['sourceCells']) == len(case['sourceWeights']) == 8, 'source layout')
        require(len(case['receiverCells']) == len(case['receiverWeights']) == 8 * receivers, 'receiver layout')
        require(len(case['velocityCells']) == receivers and len(case['axes']) == 3 * receivers, 'velocity layout')
        require(all(0 <= c < count for c in case['sourceCells'] + case['receiverCells']), 'mapped cell addresses')
        destinations = case['preparedSourceCells']; weights = case['preparedSourceWeights']
        require(len(destinations) == len(weights) and len(set(destinations)) == len(destinations), 'unique prepared source')
        require(all(0 <= c < count and case['inside'][c] == 1 for c in destinations), 'active prepared source')
        # Every retained coefficient is exactly an original Float coefficient, including unique zero slots.
        original = list(zip(case['sourceCells'], case['sourceWeights']))
        require(all((cell, weight) in original for cell, weight in zip(destinations, weights)), 'no source rescaling')
        require(all(weight == 0 or cell in destinations for cell, weight in original), 'all nonzero source writes retained')
        require(len(case['runs']) == len(STEPS) and {r['steps'] for r in case['runs']} == STEPS, 'complete batch edge histories')
        for run in case['runs']:
            compare_channels(run, receivers, run['steps'], 64)
            total += receivers * run['steps']
        require(any(v != 0 for row in case['runs'][-1]['original'] for v in row), 'nontrivial forcing')
    require(total == 36696, 'complete mixed sample count')
    timings = report['timings']
    require(len(timings) == 3 and {t['topFrequency'] for t in timings} == {100, 200, 450}, 'timing grid tree')
    for timing in timings:
        require(timing['cellCount'] == math.prod(timing['dimensions']) and timing['steps'] == 1024, 'timing scope')
        require(len(timing['originalSeconds']) == len(timing['sharedSeconds']) == 3, 'balanced repeated timing')
        for key in ('layoutSeconds', 'sharedPreparationSeconds', 'sharedInitializationSeconds'):
            require(timing[key] > 0 and math.isfinite(timing[key]), 'preparation timing')
        require(all(t > 0 and math.isfinite(t) for t in timing['originalSeconds'] + timing['sharedSeconds']), 'run timing')
        ratio = sorted(timing['sharedSeconds'])[1] / sorted(timing['originalSeconds'])[1]
        require(math.isclose(ratio, timing['sharedToOriginalMedian'], rel_tol=1e-14), 'timing ratio')
    generator = json.loads((root / 'generator.json').read_text())
    require(generator['settings']['lowFrequencyModel'] is True, 'wave-enabled complete generator')
    frames = round(generator['settings']['duration'] * generator['settings']['sampleRate'])
    compare_channels(generator, 2, frames, 32)
    original = dict(generator['originalDiagnostics']); shared = dict(generator['sharedDiagnostics'])
    for key in ('generationSeconds', 'waveSeconds'): original.pop(key, None); shared.pop(key, None)
    default = dict(generator['applicationDefaultDiagnostics'])
    for key in ('generationSeconds', 'waveSeconds'): default.pop(key, None)
    require(original == shared == default and original['waveRuns'] > 0 and original['waveGPURuns'] == 0, 'complete generator diagnostics/actual CPU wave runs')
    metadata_reports = []
    for name in ('original', 'shared', 'application-default'):
        require((root / (name + '.wav')).stat().st_size > frames * 2 * 4, 'complete saved WAV')
        metadata = json.loads((root / (name + '-metadata.json')).read_text())
        require(metadata['generatorDetails']['settings'] == generator['settings'], 'saved settings identity')
        for key in ('generationSeconds', 'waveSeconds'): metadata['generatorDetails']['diagnostics'].pop(key, None)
        metadata_reports.append(metadata)
    require(metadata_reports[0] == metadata_reports[1] == metadata_reports[2], 'complete non-timing saved metadata')
    require((root / 'original.wav').read_bytes() == (root / 'shared.wav').read_bytes() == (root / 'application-default.wav').read_bytes(), 'complete saved WAV byte parity')
    return {'schemaVersion': 1, 'status': 'passed', 'candidate': environment['revision'], 'backend': 'cpu', 'completeCases': len(CASES), 'completeRuns': len(CASES) * len(STEPS), 'mixedSamplesPerImplementation': total, 'runtimeBitMismatches': 0, 'fullGeneratorFramesPerChannel': frames, 'nonTimingDiagnostics': 'exact', 'performance': 'measured; not an acceptance threshold', 'timingRatios': [t['sharedToOriginalMedian'] for t in timings]}

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('root', type=Path); args = p.parse_args()
    result = verify(args.root)
    (args.root / 'production-verification.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print('PASS complete CPU production output and generator reports:', result['mixedSamplesPerImplementation'], 'mixed samples; timing ratios', result['timingRatios'])
