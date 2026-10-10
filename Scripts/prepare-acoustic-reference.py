#!/usr/bin/env python3
"""Bind current RoomCAD CPU update blocks and exact Metal kernel/Grid source; no stored old copies."""
import argparse
from original_wave_reference import original_metal_source
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=True)
s=(a.root/'Sources/AcousticCore/WaveSolver.swift').read_text()
start=s.index('        let kx = Float(dt / dx)')
end=s.index('        for n in 0..<steps {',start)
coefficients=s[start:end]
start=s.index('            // Velocity from the pressure gradient (ρ = 1).',end)
end=s.index('            // Volume velocity injected at the source, at the half step.',start)
updates=s[start:end]
wrapper='''import Foundation
final class SourceCPU {
 let nx:Int,ny=4,nz=4,slabs=1
 let c:Double,dt:Double,dx:Double,dy=0.125/4,dz=0.125/4
 var p,ux,uy,uz:[Float]
 let west,east,south,north,floor,ceiling:[Float]
 init(nx:Int,c:Double,dt:Double,dx:Double,p:[Float],u:[Float]) {
  self.nx=nx;self.c=c;self.dt=dt;self.dx=dx
  self.p=p;ux=u;uy=Array(repeating:0,count:p.count);uz=uy
  west=Array(repeating:0,count:16);east=west
  south=Array(repeating:0,count:nx*4);north=south;floor=south;ceiling=south
 }
 func advance(_ steps:Int) {
  func forEachSlab(_ body:(Int)->Void) { body(0) }
'''+coefficients+'\nfor _ in 0..<steps {\n'+updates+'\n}\n}\n}\n'
(a.output/'SourceCPU.swift').write_text(wrapper)
s=original_metal_source(a.root)
start=s.index('    struct Grid {');end=s.index('\n    /// Simulates',start);grid=s[start:end]
start=s.index('    static let source = """');end=s.index('\n}\n\nextension WaveSolver',start);kernel=s[start:end]
(a.output/'SourceMetal.swift').write_text('enum SourceMetal {\n'+grid+'\n'+kernel+'\n}\n')
