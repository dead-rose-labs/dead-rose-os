#!/usr/bin/env python3
"""Cheap repository invariants; upstream schema and tools own format validation."""
import ast
import datetime
import os
from pathlib import Path
import re
import sys
import yaml

root = Path(__file__).resolve().parents[1]
floating_arch_refs = ('archlinux:' + 'latest', 'archlinux' + '/base')

def require(ok, message):
    if not ok:
        sys.exit(message)

values = {}
for line in (root / 'versions.env').read_text().splitlines():
    if not line or line.startswith('#'):
        continue
    require(bool(re.fullmatch(r'[A-Z0-9_]+=[A-Za-z0-9./:_-]+', line)), 'versions.env must contain literal assignments only')
    key, value = line.split('=', 1)
    require(key not in values, f'Duplicate version key: {key}')
    values[key] = value
for key, pattern in {
    'DEAD_ROSE_VERSION': r'\d+\.\d+\.\d+', 'ARCH_SNAPSHOT': r'\d{4}/\d{2}/\d{2}',
    'CALAMARES_VERSION': r'\d+\.\d+\.\d+', 'CALAMARES_COMMIT': r'[0-9a-f]{40}',
    'CALAMARES_SHA256': r'[0-9a-f]{64}', 'ARCH_CONTAINER_DIGEST': r'sha256:[0-9a-f]{64}',
    'ARCH_CONTAINER_REPOSITORY': r'ghcr.io/archlinux/archlinux',
}.items():
    require(bool(re.fullmatch(pattern, values.get(key, ''))), f'Invalid or missing pin: {key}')
datetime.datetime.strptime(values['ARCH_SNAPSHOT'], '%Y/%m/%d')
mirror_template = (root / 'config/system/mirrorlist.in').read_text().strip()
require(mirror_template == 'Server = https://archive.archlinux.org/repos/@ARCH_SNAPSHOT@/$repo/os/$arch',
        'Target mirrorlist must use the central Arch Linux Archive snapshot token')
require((root / 'VERSION').read_text().strip() == values['DEAD_ROSE_VERSION'], 'VERSION disagrees with versions.env')
if os.environ.get('GITHUB_REF_TYPE') == 'tag':
    require(os.environ['GITHUB_REF_NAME'] == 'v' + values['DEAD_ROSE_VERSION'], 'Tag version disagrees with versions.env')
for path in list(root.glob('ci/**/*.py')) + list(root.glob('scripts/*.py')):
    ast.parse(path.read_text(), str(path))
for path in root.glob('.github/workflows/*.yml'):
    text = path.read_text()
    require('pull_request_target' not in text, 'PR code must not execute with privileged event context')
    require('continue-on-error' not in text, 'Required stages cannot ignore failures')
    require('@main' not in text and '@master' not in text, f'Floating action ref in workflow: {path}')
    require(all(ref not in text for ref in floating_arch_refs),
            f'Floating Arch container reference: {path}')
    workflow = yaml.safe_load(text)
    for job in workflow['jobs'].values():
        require('timeout-minutes' in job or (job.get('uses') == './.github/workflows/arch-stage.yml' and 'timeout' in job.get('with', {})), 'Every job needs a timeout')
    for action in re.findall(r'uses:\s*(\S+)', text):
        require(action == './.github/workflows/arch-stage.yml' or bool(re.fullmatch(r'actions/[\w-]+@[0-9a-f]{40}', action)), f'Unpinned or nonofficial action: {action}')
for path in root.glob('packaging/*/PKGBUILD'):
    text = path.read_text()
    require("'SKIP'" not in text and '"SKIP"' not in text, f'Unchecked package source: {path}')
    require('sha256sums=' in text, f'Missing source checksums: {path}')
partition_config = (root / 'calamares/modules/partition.conf').read_text()
for key in ('defaultPartitionTableType', 'requiredPartitionTableType'):
    require(key not in partition_config, f'Unsupported Calamares partition key returned: {key}')
upstream = (root / 'packaging/calamares/PKGBUILD').read_text()
require('_revision=$CALAMARES_COMMIT' in upstream and 'sha256sums=("$CALAMARES_SHA256")' in upstream,
        'Calamares must consume central commit and checksum pins')
require('deadrose-installer' not in upstream and 'deadrose-config.tar' not in upstream,
        'Upstream binary and installer config must be separate packages')
for path in list(root.glob('ci/**/*')) + list(root.glob('scripts/*')) + list(root.glob('archiso/**/*')) + [root / 'dr']:
    if path.is_file() and path.suffix not in {'.md', '.png', '.svg'}:
        text = path.read_text(errors='ignore')
        require(all(ref not in text for ref in floating_arch_refs),
                f'Floating Arch container reference: {path}')
for path in list(root.glob('ci/**/*.sh')) + list(root.glob('scripts/*.sh')) + [root / 'dr']:
    require('set -Eeuo pipefail' in path.read_text(), f'Strict shell mode missing: {path}')
    require(not re.search(r'(curl|wget)[^\n]+\|\s*(bash|sh)', path.read_text()), f'Unverified execution: {path}')
print('Pins, versions, source integrity policy and workflow structure passed.')
