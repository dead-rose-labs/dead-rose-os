#!/usr/bin/env python3
"""Portable source checks; boot and installation require separate acceptance."""
from pathlib import Path
import re
import sys
import ast
import json
import xml.etree.ElementTree as ET
import yaml

root = Path(__file__).resolve().parents[1]
profile = root / 'archiso'

def require(condition, message):
    if not condition:
        sys.exit(message)

for name in ('profiledef.sh', 'pacman.conf', 'packages.x86_64',
             'efiboot/loader/loader.conf',
             'efiboot/loader/entries/01-dead-rose.conf',
             'airootfs/etc/mkinitcpio.d/linux.preset',
             'airootfs/etc/mkinitcpio.conf.d/archiso.conf',
             'airootfs/etc/plymouth/plymouthd.conf',
             'airootfs/etc/sddm.conf.d/10-live.conf'):
    require((profile / name).is_file(), f'Missing profile file: {name}')

packages = [line.strip() for line in (profile / 'packages.x86_64').read_text().splitlines()
            if line.strip() and not line.startswith('#')]
require(len(packages) == len(set(packages)), 'Duplicate packages')
require(all(re.fullmatch(r'[a-z0-9][a-z0-9@+_.-]*', p) for p in packages), 'Invalid package name')
required = {'base', 'linux', 'mkinitcpio', 'mkinitcpio-archiso', 'plasma-desktop',
            'plasma-workspace', 'kwin', 'sddm', 'networkmanager', 'chromium',
            'dolphin', 'konsole', 'systemsettings', 'pipewire', 'wireplumber', 'btrfs-progs',
            'calamares', 'dead-rose-config', 'dead-rose-calamares-config', 'plymouth', 'grub'}
require(required <= set(packages), f'Missing packages: {required - set(packages)}')
require(not {'plasma-meta', 'kde-applications-meta', 'cage', 'greetd'} & set(packages), 'Forbidden base packages')
config = (profile / 'profiledef.sh').read_text()
require('bootmodes=(\'uefi.systemd-boot\')' in config, 'Expected UEFI systemd-boot profile')
require('DEAD_ROSE_ISO_VERSION' in config, 'Profile must consume factory version + commit')
pacman = (profile / 'pacman.conf').read_text()
require(re.findall(r'^\[([^]]+)\]', pacman, re.M) == ['options', 'core', 'extra'], 'Unexpected package repository')
require('SigLevel = Required DatabaseOptional' in pacman, 'Package signature verification required')
for path, target in {
    'default.target': '/usr/lib/systemd/system/graphical.target',
    'display-manager.service': '/usr/lib/systemd/system/sddm.service',
    'multi-user.target.wants/NetworkManager.service': '/usr/lib/systemd/system/NetworkManager.service',
}.items():
    link = profile / 'airootfs/etc/systemd/system' / path
    require(link.is_symlink() and str(link.readlink()) == target, f'Incorrect service link: {path}')
require((profile / 'airootfs/etc/shadow').read_text().startswith('root:!:'), 'Root must be locked')
for path in root.glob('branding/**/*.svg'):
    ET.parse(path)
for path in root.glob('branding/**/metadata.json'):
    json.loads(path.read_text())
for path in root.glob('scripts/*.py'):
    ast.parse(path.read_text(), filename=str(path))
ast.parse((root / 'apps/web-app/dead-rose-web-app').read_text())
for name in ('branding/colors/DeadRose.colors', 'branding/sddm/Main.qml',
             'branding/plymouth/deadrose.script', 'branding/wallpapers/dead-rose.svg',
             'branding/calamares/branding.desc', 'branding/icons/index.theme',
             'branding/plasma/look-and-feel/contents/layouts/org.kde.plasma.desktop-layout.js'):
    require((root / name).is_file(), f'Missing branding asset: {name}')
settings = yaml.safe_load((root / 'calamares/settings.conf').read_text())
steps = [step for phase in settings['sequence'] for step in phase.get('exec', [])]
for needed in ('partition', 'unpackfs', 'removeuser', 'users', 'initcpio', 'bootloader', 'packages', 'shellprocess@verify', 'umount'):
    require(needed in steps, f'Missing installer step: {needed}')
require(steps.index('removeuser') < steps.index('users'), 'Remove live user before allocating installed UID')
require(steps.index('initcpio') < steps.index('bootloader') < steps.index('shellprocess@verify'), 'Invalid boot setup ordering')
modules = {}
for path in (root / 'calamares/modules').glob('*.conf'):
    modules[path.stem] = yaml.safe_load(path.read_text())
require(modules['users']['setRootPassword'] is False, 'Root login must stay disabled')
require(modules['users']['doAutologin'] is False, 'Installed autologin must default off')
require(modules['partition']['initialPartitioningChoice'] == 'none', 'Disk action must require explicit choice')
require(modules['partition']['defaultFileSystemType'] == 'btrfs', 'Btrfs must be default')
require(modules['packages']['update_db'] is False, 'Offline install must not require package refresh')
workflow_text = (root / '.github/workflows/factory.yml').read_text()
for action in re.findall(r'uses:\s*(\S+)', workflow_text):
    require(action == './.github/workflows/arch-stage.yml' or re.fullmatch(r'[\w-]+/[\w-]+@[0-9a-f]{40}', action), f'Action must use commit SHA: {action}')
yaml.safe_load(workflow_text)
print(f'Profile source checks passed ({len(packages)} explicit packages).')
