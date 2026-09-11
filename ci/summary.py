#!/usr/bin/env python3
import json
import os
from pathlib import Path

artifacts = Path(os.environ['ARTIFACTS'])
print('## 🌹 Dead Rose OS Factory\n')
for key in ('DEAD_ROSE_VERSION', 'GIT_COMMIT', 'ARCH_SNAPSHOT', 'CALAMARES_COMMIT'):
    print(f"- {key}: `{os.environ[key]}`")
print('\n| Stage | Result |\n| --- | --- |')
for path in sorted((artifacts / 'status').glob('*')):
    print(f'| {path.name} | {path.read_text().strip()} |')
manifest = artifacts / 'manifest/build.json'
if manifest.exists():
    data = json.loads(manifest.read_text())
    print(f"\nISO: `{data['iso_filename']}`\n\nSize: {data['iso_size_bytes'] / 1024**3:.2f} GiB\n\nSHA256: `{data['iso_sha256']}`")
result = artifacts / 'logs/qemu-result.json'
if result.exists():
    data = json.loads(result.read_text())
    print(f"\nQEMU: {data['reason']} ({data['acceleration']})")
    for marker, passed in data['markers'].items():
        print(f"- {'✅' if passed else '❌'} {marker}")
