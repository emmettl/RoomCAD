#!/usr/bin/env python3
"""Inject reversible fixture-only trace hooks into the actual fitting callers."""
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
sys.dont_write_bytecode=True
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--mode',choices=['original','shared'],required=True);a=p.parse_args()
root=a.root.resolve();out=a.output.resolve();fixture=root/'Fixtures/AffineAdoptionBenchmark'
if out.is_relative_to(root/'Sources'):raise ValueError('Fixture trace must never be written into production')
sys.path.insert(0,str(root/'Scripts'));from original_fitting_reference import original_fitting_sources
originals=original_fitting_sources(root,True)
shutil.copytree(root/'Sources/AcousticCore',out/'Sources/AcousticCore')
shutil.copytree(root/'Sources/RoomDocument',out/'Sources/RoomDocument')
shutil.copytree(fixture/'Sources/AffineAdoptionBenchmark',out/'Sources/AffineAdoptionBenchmark')
shared=a.mode=='shared';source={}
for name in ['RoomParameters.swift','DecayAnalysis.swift']:
 raw=(root/'Sources/AcousticCore'/name).read_bytes() if shared else originals[name]
 text=raw.decode();patches=[]
 def patch(old,new,label):
  global text
  if text.count(old)!=1:raise ValueError('Trace binding missing/ambiguous '+name+':'+label)
  text=text.replace(old,new);patches.append({'label':label,'original':old,'traced':new})
 def before(anchor,call,label):patch(anchor,'        '+call+'\n'+anchor,label)
 def after(anchor,call,label):patch(anchor,anchor+'\n        '+call,label)
 if name=='RoomParameters.swift':
  before('        var end = energy.count','AffineTrace.roomEnergy(energy, sampleRate, noiseCompensated)','actual energy input')
  after('        let decibels = curve.map { 10 * log10(max($0, .leastNonzeroMagnitude) / total) }','AffineTrace.roomCurve(curve, decibels, total, tail, end)','actual backward curve')
  anchor='            guard let slope = slopePerSecond(decibels, first...last, sampleRate: rate) else { return nil }' if shared else '            let slope = slopePerSecond(decibels, first...last, sampleRate: rate)'
  before(anchor,'AffineTrace.roomWindow(decibels, first, last, rate, upper, lower)','actual time window')
  before('        guard top - floor > 20 else { return nil }','AffineTrace.noiseSetup(means, levels, smoothed, block, blocks, top, floor)','actual block setup')
  after('            let last = (smoothed[(first + 1)...].firstIndex { $0 < floor + 10 } ?? blocks) - 1','AffineTrace.noiseWindow(first, last, floor, top)','actual noise window')
  before('            return 10 * log10(max(mean, 1e-300))','AffineTrace.record("noise-floor", ["index": index, "start": start, "mean": AffineTrace.scalar(mean)])','actual noise estimate')
  if shared:
   before('            slope = fit.slope','AffineTrace.crossing(coordinate, cut, nextStart)','actual checked crossing')
   after('            floor = noise(from: nextStart)','AffineTrace.noiseIteration(crossing, slope, floor)','actual next floor')
   old='        return try? AffineLeastSquares.fit(x: coordinates, y: values)'
   patch(old,'        let result = try? AffineLeastSquares.fit(x: coordinates, y: values)\n        AffineTrace.sharedLine(values, offset, result)\n        return result','capture identical public fit expression')
  else:
   after('            crossing = min(max(Int((floor - intercept) / slope), last), blocks - 1)','AffineTrace.crossing((floor - intercept) / slope, crossing, nil)','actual original crossing')
   after('            floor = noise(from: crossing + Int(5 / -slope) + 1)','AffineTrace.noiseIteration(crossing, slope, floor)','actual original next floor')
   before('        return (slope, (sy - slope * sx) / n)','AffineTrace.legacyLine(values, offset, slope, (sy - slope * sx) / n)','actual original coefficient expression')
  before('        return (index, perSample * tau)','AffineTrace.noiseTail(index, level, perSample, tau)','actual tail expression')
  patch('private static func line(', 'static func line(', 'fixture-only probe visibility')
 else:
  anchor='        guard sampleRate > 0,' if shared else '        let n = Double(last - first + 1)'
  before(anchor,'AffineTrace.decayWindow(samples, curve, sampleRate, upper, lower, first, last)','actual seconds window')
  call='AffineTrace.sharedDecayFit(curve, first, last, sampleRate, fit)' if shared else 'AffineTrace.legacyDecayFit(curve, first, last, sampleRate, slope)'
  before('        return slope < 0 ? -60 / slope : nil',call,'actual seconds fit')
 reversed_text=text
 for change in reversed(patches):
  if reversed_text.count(change['traced'])!=1:raise ValueError('Trace restoration ambiguous')
  reversed_text=reversed_text.replace(change['traced'],change['original'])
 if reversed_text.encode()!=raw:raise ValueError('Trace altered actual fitting source')
 (out/'Sources/AcousticCore'/name).write_text(text)
 source[name]={'originalSHA256':hashlib.sha256(raw).hexdigest(),'instrumentedSHA256':hashlib.sha256(text.encode()).hexdigest(),'patches':patches}
shutil.copyfile(fixture/'Trace.swift',out/'Sources/AcousticCore/AffineTrace.swift')
version='0.1.0-alpha.18' if shared else '0.1.0-alpha.17'
products=['ImpulseResponseKit','SpectralTransforms','LinearAcoustics','LinearAcousticsMetal']+(['Numerics'] if shared else [])
links=', '.join('.product(name: "'+n+'", package: "continuumkit")' for n in products)
settings='[.define("ROOMCAD_SHARED_WAVE_DEFAULT")'+(', .define("TRACE_SHARED_AFFINE")' if shared else '')+']'
manifest='''// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "RoomCADAffineAdoptionBenchmark", platforms: [.macOS(.v15)], dependencies: [.package(url: "https://github.com/emmettl/ContinuumKit.git", exact: "VERSION")], targets: [
.target(name: "AcousticCore", dependencies: [LINKS], swiftSettings: SETTINGS),
.target(name: "RoomDocument", dependencies: ["AcousticCore", .product(name: "DocumentKit", package: "continuumkit"), .product(name: "ImpulseResponseKit", package: "continuumkit")]),
.executableTarget(name: "AffineAdoptionBenchmark", dependencies: ["AcousticCore", "RoomDocument", .product(name: "ImpulseResponseKit", package: "continuumkit")])], swiftLanguageModes: [.v6])
'''.replace('VERSION',version).replace('LINKS',links).replace('SETTINGS',settings)
(out/'Package.swift').write_text(manifest)
d={'schemaVersion':1,'mode':a.mode,'sourceProducer':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'originalFittingProducer':'bf869284f29b7604a08d98cf66cf8a2c5619e525','exactVersion':version,'sources':source,'scope':'fixture-only reversible statement traces; original numerical statements and public fit expression unchanged','traceSHA256':hashlib.sha256((fixture/'Trace.swift').read_bytes()).hexdigest(),'manifestSHA256':hashlib.sha256(manifest.encode()).hexdigest(),'fixtureMainSHA256':hashlib.sha256((fixture/'Sources/AffineAdoptionBenchmark/Main.swift').read_bytes()).hexdigest(),'preparerSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'compiledSourceHashes':{str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((out/'Sources').rglob('*')) if p.is_file()}}
(out/'source-bindings.json').write_text(json.dumps(d,indent=2,sort_keys=True)+'\n')
print('PASS reversible',a.mode,'actual fitting-source traces and exact',version,'dependency')
