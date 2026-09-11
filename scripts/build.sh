#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
    echo 'Build requires Arch Linux x86_64 (a Linux VM is supported). See docs/build.md.' >&2
    exit 1
fi
if (( EUID != 0 )); then
    exec sudo -- "$0" "$@"
fi
command -v mkarchiso >/dev/null || { echo 'Install archiso first: pacman -Syu archiso' >&2; exit 1; }
work=${DEAD_ROSE_WORK_DIR:-$repo/work}
out=${DEAD_ROSE_OUT_DIR:-$repo/out}
if [[ -e "$work" ]]; then
    echo "Work directory already exists: $work. Use a fresh DEAD_ROSE_WORK_DIR to avoid stale Archiso build steps." >&2
    exit 1
fi
mkdir -p "$out"
mkdir -p "$work"
"$repo/scripts/build-packages.sh" "$work/packages"
# Assemble a temporary profile; mkarchiso remains the only ISO builder.
cp -a "$repo/archiso" "$work/profile"
# The live account is pre-created by Archiso, so useradd does not copy /etc/skel.
# Give it the same initial defaults that Calamares supplies to installed users.
live_config="$work/profile/airootfs/home/live/.config"
mkdir -p "$live_config/menus"
for conf in kdeglobals plasmarc kwinrc kcminputrc konsolerc; do
    cp "$repo/config/plasma/$conf" "$live_config/$conf"
done
cat "$repo/branding/colors/DeadRose.colors" >> "$live_config/kdeglobals"
cp "$repo/config/plasma/plasma-applications.menu" "$live_config/menus/"
cat >> "$work/profile/pacman.conf" <<EOF

[deadrose-local]
SigLevel = Optional TrustAll
Server = file://$work/packages/repo
EOF
mkarchiso -v -w "$work/archiso" -o "$out" "$work/profile"
cp "$work/archiso/iso/arch/pkglist.x86_64.txt" "$out/packages.x86_64.txt"
(cd "$out" && sha256sum dead-rose-os-0.1.0-x86_64.iso > SHA256SUMS)
"$repo/scripts/test.sh" --iso "$out/dead-rose-os-0.1.0-x86_64.iso"
