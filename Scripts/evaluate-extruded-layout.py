#!/usr/bin/env python3
"""Apply the pinned independent geometry oracle; preserve explicit assignment gaps."""
import argparse,importlib.util,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--core',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
spec=importlib.util.spec_from_file_location('extruded_layout',a.core/'Scripts/extruded_layout.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
for path in sorted(a.output.glob('*.layout.json')):
 record=json.loads(path.read_text());record['metrics']=module.evaluate(record['specification'],record['layout'])
 path.write_text(json.dumps(record,separators=(',',':'))+'\n')
module.verify(a.output)
