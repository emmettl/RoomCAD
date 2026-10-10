#!/usr/bin/env python3
"""Copy current geometry/Metal access; bind immutable update and FFT compile controls."""
import argparse,shutil
from original_wave_reference import original_masked_source, copy_original_masked_reference
from original_fft_reference import copy_original_fft_reference
from original_fitting_reference import copy_original_fitting_reference
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
# These original source-free fixtures pin Core versions before production source/receiver APIs.
# The optional shared app backend is verified separately; original update/layout source stays verbatim.
shutil.copytree(a.root/'Sources/AcousticCore',a.output/'Sources/AcousticCore',ignore=shutil.ignore_patterns('SharedWaveSimulation.swift', 'SharedMetalSimulation.swift'))
copy_original_masked_reference(a.root, a.output/'Sources/AcousticCore')
# These frozen Core pins predate SpectralTransforms. Bind only the protected
# verification FFT; current application adoption has its separate full-output gate.
copy_original_fft_reference(a.root, a.output/'Sources/AcousticCore')
copy_original_fitting_reference(a.root, a.output/'Sources/AcousticCore')
source=original_masked_source(a.root)
start=source.index('    func simulateMasked(')
coeff_start=source.index('        let kx = Float(dt / spacing.x)',start)
loop=source.index('        for n in 0..<steps {',coeff_start)
coefficients=source[coeff_start:loop]
start=source.index('            // Velocity on faces between two simulated cells;',loop)
end=source.index('            let q = pulse(',start)
updates=source[start:end]
wrapper='''import Foundation
import simd
@testable import AcousticCore
final class SourceAbsorbingCylinderCPU {
 let nx,ny,nz:Int,slabs=1
 let c,dt:Double
 let spacing:SIMD3<Double>
 let inside:[Bool],faces:[[Float]]
 let p,ux,uy,uz:UnsafeMutablePointer<Float>
 let count:Int
 init(nx:Int,ny:Int,nz:Int,c:Double,dt:Double,spacing:SIMD3<Double>,layout:WaveSolver.GridLayout,
      pressure:[Float],u:[Float],v:[Float],w:[Float]) {
  self.nx=nx;self.ny=ny;self.nz=nz;self.c=c;self.dt=dt;self.spacing=spacing;count=nx*ny*nz
  inside=layout.inside.map{$0==1}
  faces=(0..<6).map{Array(layout.faces[($0*layout.count)..<(($0+1)*layout.count)])}
  func pointer(_ a:[Float])->UnsafeMutablePointer<Float> {
   let p=UnsafeMutablePointer<Float>.allocate(capacity:a.count)
   for i in a.indices {p.advanced(by:i).initialize(to:a[i])};return p
  }
  p=pointer(pressure);ux=pointer(u);uy=pointer(v);uz=pointer(w)
 }
 deinit {for field in [p,ux,uy,uz] {field.deinitialize(count:count);field.deallocate()}}
 func fields()->(p:[Float],u:[Float],v:[Float],w:[Float]) {
  func values(_ p:UnsafeMutablePointer<Float>)->[Float] {Array(UnsafeBufferPointer(start:p,count:count))}
  return (values(p),values(ux),values(uy),values(uz))
 }
 func advance(_ steps:Int) {
  let plane=nx*ny
  func forEachSlab(_ body:(Int)->Void) {body(0)}
'''+coefficients+'\nfor _ in 0..<steps {\n'+updates+'\n}\n}\n}\n'
(a.output/'Sources/AbsorbingCylinderAdapter/SourceAbsorbingCylinderCPU.swift').write_text(wrapper)
