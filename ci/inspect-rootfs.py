#!/usr/bin/env python3
import os
from pathlib import Path
import sys

tree = Path(sys.argv[1])
required = [
    'usr/bin/calamares', 'etc/calamares/settings.conf', 'etc/calamares/branding/deadrose/branding.desc',
    'usr/share/wayland-sessions/plasma.desktop', 'etc/sddm.conf.d/10-live.conf',
    'usr/share/plasma/look-and-feel/org.deadrose.desktop/contents/layouts/org.kde.plasma.desktop-layout.js',
    'usr/share/wallpapers/DeadRose/contents/images/3840x2160.png',
    'usr/share/sddm/themes/deadrose/Main.qml', 'usr/share/plymouth/themes/deadrose/logo.png',
    'usr/local/bin/dead-rose-live-check', 'usr/share/dead-rose/os-release',
]
for name in required:
    if not (tree / name).is_file() or not (tree / name).stat().st_size:
        sys.exit(f'Missing/empty ISO file: {name}')
for module in ('partition', 'users', 'unpackfs', 'bootloader', 'initcpio', 'shellprocess'):
    if not (tree / 'usr/lib/calamares/modules' / module / 'module.desc').is_file():
        sys.exit(f'Missing installer module: {module}')
packages = dict(line.split(maxsplit=1) for line in (Path(os.environ['ARTIFACTS']) / 'manifest/packages.txt').read_text().splitlines())
for name in ('linux', 'calamares', 'dead-rose-calamares-config', 'dead-rose-config',
             'plasma-workspace', 'plasma-desktop', 'kwin', 'networkmanager', 'sddm', 'plymouth'):
    if name not in packages:
        sys.exit(f'Missing ISO package: {name}')
mirror = (tree / 'etc/pacman.d/mirrorlist').read_text().strip()
expected = f"Server = https://archive.archlinux.org/repos/{os.environ['ARCH_SNAPSHOT']}/$repo/os/$arch"
if mirror != expected:
    sys.exit('Installed mirrorlist differs from the pinned snapshot')
if 'ID_LIKE=arch' not in (tree / 'usr/share/dead-rose/os-release').read_text():
    sys.exit('Arch lineage missing from os-release')
if not (tree / 'etc/shadow').read_text().startswith('root:!:'):
    sys.exit('Root login must remain locked')
print('ISO contents, installer modules, desktop assets and snapshot passed.')
