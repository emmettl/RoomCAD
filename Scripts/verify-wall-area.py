#!/usr/bin/env python3
"""Require physical side-area conformance after the layout correction.

The independent audit validator must run first. Historical gap reports are retained
unchanged; current production source must pass this additional application gate.
"""
import json
import sys
from pathlib import Path

records = json.loads((Path(sys.argv[1]) / "results.json").read_text())
assert len(records) == 12
assert {r["specification"]["id"] for r in records} == {
    "aligned-box-control", "absorbing-cylinder"
}
assert all(r["physicalStatus"] == "passed" and r["numericalStatus"] == "passed"
           and r["status"] == "supported" for r in records)
assert all(r["errors"]["areaRelativeError"] < 0.005 for r in records)
print("PASS actual physical wall area and isolated numerical flow: 12 records")
