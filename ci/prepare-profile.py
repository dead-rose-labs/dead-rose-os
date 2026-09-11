#!/usr/bin/env python3
"""Stage the version-controlled profile/templates before mkarchiso; never edit ISO/rootfs."""
import os
from pathlib import Path
import shutil

root = Path(os.environ['FACTORY_ROOT'])
work = Path(os.environ['FACTORY_WORK'])
profile = work / 'profile'
shutil.copytree(root / 'archiso', profile, symlinks=True)
mirrorlist = (root / 'config/system/mirrorlist.in').read_text().replace('@ARCH_SNAPSHOT@', os.environ['ARCH_SNAPSHOT'])
(profile / 'airootfs/etc/pacman.d/mirrorlist').write_text(mirrorlist)
with (profile / 'pacman.conf').open('a') as f:
    f.write('\n[deadrose]\nSigLevel = Optional TrustAll\nServer = ' + (work / 'repository').as_uri() + '\n')
live_config = profile / 'airootfs/home/live/.config'
(live_config / 'menus').mkdir(parents=True)
for name in ('kdeglobals', 'plasmarc', 'kwinrc', 'kcminputrc', 'konsolerc'):
    shutil.copyfile(root / 'config/plasma' / name, live_config / name)
with (live_config / 'kdeglobals').open('a') as f:
    f.write((root / 'branding/colors/DeadRose.colors').read_text())
shutil.copyfile(root / 'config/plasma/plasma-applications.menu', live_config / 'menus/plasma-applications.menu')
overlay = profile / 'airootfs'
shutil.copyfile(root / 'ci/live/dead-rose-live-check.sh', overlay / 'usr/local/bin/dead-rose-live-check')
shutil.copyfile(root / 'ci/live/dead-rose-live-check.service', overlay / 'etc/systemd/system/dead-rose-live-check.service')
(overlay / 'etc/modules-load.d').mkdir(parents=True, exist_ok=True)
shutil.copyfile(root / 'ci/live/modules.conf', overlay / 'etc/modules-load.d/deadrose-ci.conf')
