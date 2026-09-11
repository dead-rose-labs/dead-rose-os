#!/usr/bin/env python3
import datetime
import json
import os
from pathlib import Path

artifacts = Path(os.environ['ARTIFACTS'])
name = os.environ['ISO_NAME']
packages = dict(line.split(maxsplit=1) for line in (artifacts / 'manifest/packages.txt').read_text().splitlines())
manifest = {
    'dead_rose_version': os.environ['DEAD_ROSE_VERSION'],
    'git_commit': os.environ['GIT_COMMIT'],
    'git_short_sha': os.environ['GIT_SHORT_SHA'],
    'arch_snapshot': os.environ['ARCH_SNAPSHOT'],
    'arch_container_digest': os.environ['ARCH_CONTAINER_DIGEST'],
    'archiso_version': (artifacts / 'manifest/archiso.txt').read_text().split()[1],
    'calamares_commit': os.environ['CALAMARES_COMMIT'],
    'calamares_version': packages['calamares'],
    'kernel_version': packages['linux'],
    'workflow_run_id': os.environ.get('GITHUB_RUN_ID', 'local'),
    'build_timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'source_date_epoch': int(os.environ['SOURCE_DATE_EPOCH']),
    'iso_filename': name,
    'iso_size_bytes': (artifacts / name).stat().st_size,
    'iso_sha256': (artifacts / (name + '.sha256')).read_text().split()[0],
}
(artifacts / 'manifest/build.json').write_text(json.dumps(manifest, indent=2) + '\n')
