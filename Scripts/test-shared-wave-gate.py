#!/usr/bin/env python3
"""Reject interrupted/partial producers and missing suite/field records on macOS Bash."""
import json,subprocess,tempfile,unittest
from pathlib import Path
root=Path(__file__).resolve().parents[1]
class GateControls(unittest.TestCase):
 def test_incomplete_success_status_becomes_failure(self):
  # Bash 3.2 can enter EXIT with $?=0 after an unset-variable expansion. Never certify early exit.
  with tempfile.TemporaryDirectory() as folder:
   source=(root/'Scripts/check-shared-waves.sh').read_text().splitlines()
   trap=next(line for line in source if line.startswith("trap '"))
   self.assertIn('task_completed=0',source)
   code='set -euo pipefail; task_completed=0; scratch='+folder+'; '+trap+'; arguments=(); printf "%s" "${arguments[@]}"'
   result=subprocess.run(['/bin/bash','-c',code],capture_output=True,text=True)
   self.assertNotEqual(result.returncode,0)
 def test_nonempty_argument_list_works(self):
  result=subprocess.run(['/bin/bash','-c','set -euo pipefail; arguments=(--backend cpu); printf "%s\\n" "${arguments[@]}"'],capture_output=True,text=True)
  self.assertEqual(result.returncode,0);self.assertEqual(result.stdout.splitlines(),['--backend','cpu'])
 def test_empty_report_tree_cannot_pass(self):
  with tempfile.TemporaryDirectory() as folder:
   directory=Path(folder)
   result=subprocess.run(['python3',str(root/'Scripts/verify-shared-wave-pair.py'),str(directory/'original'),str(directory/'shared'),'--output',str(directory/'proof.json'),'--suites','masked'],capture_output=True,text=True)
   self.assertNotEqual(result.returncode,0);self.assertFalse((directory/'proof.json').exists())
 def test_partial_backend_tree_cannot_pass(self):
  with tempfile.TemporaryDirectory() as folder:
   directory=Path(folder);backend=directory/'shared/masked/cpu';backend.mkdir(parents=True);(backend/'results.json').write_text('[]')
   result=subprocess.run(['python3',str(root/'Scripts/verify-shared-wave-pair.py'),str(directory/'original'),str(directory/'shared'),'--output',str(directory/'proof.json'),'--suites','masked'],capture_output=True,text=True)
   self.assertNotEqual(result.returncode,0);self.assertFalse((directory/'proof.json').exists())
if __name__=='__main__':unittest.main()
