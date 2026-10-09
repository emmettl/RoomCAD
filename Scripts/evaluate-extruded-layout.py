#!/usr/bin/env python3
"""Apply the pinned independent geometry oracle; require all declared layouts to conform."""
import argparse,importlib.util,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--core',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
spec=importlib.util.spec_from_file_location('extruded_layout',a.core/'Scripts/extruded_layout.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
for path in sorted(a.output.glob('*.layout.json')):
 record=json.loads(path.read_text());record['metrics']=module.evaluate(record['specification'],record['layout'])
 path.write_text(json.dumps(record,separators=(',',':'))+'\n')
summary=module.verify(a.output)
if any(row['status']!='passed' for row in summary):
 raise ValueError('Strict extrusion regression: a declared layout has an assignment gap')
for path in sorted(a.output.glob('*.layout.json')):
 if json.loads(path.read_text()).get('unresolvedCrossings')!=[]:
  raise ValueError('Declared extrusions must resolve every boundary segment without fallback')
print('PASS strict 36-layout assignment and zero-fallback regression')
