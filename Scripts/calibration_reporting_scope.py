"""Exact permitted UI-report transformation; no acoustic/calibration policy exemption."""
OLD='''        return
            "Absorption \\(scale) in \\(steps) step\\(steps == 1 ? "" : "s"); preview T30 within \\(worst) of the "
            + "targets."'''
NEW='''        let prefix = "Absorption \\(scale) in \\(steps) step\\(steps == 1 ? "" : "s"); "
        if errors.count < used.count {
            if errors.isEmpty {
                return prefix + "preview T30 unavailable for all \\(used.count) targeted bands."
            }
            return prefix
                + "preview T30 within \\(worst) for \\(errors.count) of \\(used.count) targeted bands; "
                + "unavailable for \\(used.count - errors.count)."
        }
        return prefix + "preview T30 within \\(worst) of the targets."'''

def verify_reporting_scope(original: bytes, current: bytes):
    if current==original:return
    before=original.decode();assert before.count(OLD)==1,'unique historical report body'
    expected=before.replace(OLD,NEW).encode()
    assert current==expected,'calibration UI changed outside exact coverage-report transformation'
