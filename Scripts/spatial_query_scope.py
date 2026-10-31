"""Exact reviewed spatial-query adoption; acoustic/material policies have no exemption."""
import hashlib

ZONE = 'Sources/AcousticCore/FittingZone.swift'
ORIGINAL_SHA256 = '16a7ba8f2610b707bfa24fbbeec914ad34b2910fbdfb8dbdf08390982db219f6'
EXPECTED = {'Sources/AcousticCore/FittingZone.swift': '9bd587b6428048a0706d938e388bfebccda17f67db4347a15fae7adcd2a193db', 'Tests/AcousticCoreTests/SharedBoxQueryTests.swift': '725c4f03628325ff303bb22c24170c6755346cf71cf4c7e872c29fb2ec881e02'}
CORE_QUERY = 'Sources/SceneModel/DoubleBoxQuery.swift'
CORE_QUERY_SHA256 = '0d882377e4097245d12108a4eeec1d383edafaeefe3ca672acc9c105117a9650'

def verify_spatial_query_scope(original: bytes, current: bytes):
    assert hashlib.sha256(original).hexdigest() == ORIGINAL_SHA256, 'protected fitted-zone baseline changed'
    assert hashlib.sha256(current).hexdigest() == EXPECTED[ZONE], 'fitted-zone code changed outside reviewed shared-query adapter'

def verify_spatial_query_files(files):
    for path, expected in EXPECTED.items():
        assert path in files and hashlib.sha256(files[path]).hexdigest() == expected, 'spatial-query source changed: '+path

# Immutable reviewed tag; publication is gated by the exact-tag release workflow.
CORE_VERSION = '0.1.0-alpha.23'
CORE_REVISION = 'b5a317486f1f87dd28ddeb9733587a41061d882c'
