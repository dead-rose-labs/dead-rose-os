#!/usr/bin/env bash
set -Eeuo pipefail
# Host QEMU only; Arch packages are never installed directly into Ubuntu.
if [[ -f /etc/arch-release ]]; then
    sudo pacman -S --needed --noconfirm qemu-system-x86 edk2-ovmf python
else
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends qemu-system-x86 ovmf
fi
