#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -m)" != "x86_64" ]]; then echo "Dead Rose OS requires an amd64 builder." >&2; exit 1; fi
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "26.04" ]]; then echo "Supported builder: Ubuntu 26.04 LTS amd64." >&2; exit 1; fi

sudo apt-get update
sudo apt-get install -y build-essential clang curl dosfstools git grub-efi-amd64-bin jq libwebkit2gtk-4.1-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev live-boot mkosi mtools ovmf pkg-config qemu-system-x86 qemu-utils squashfs-tools xorriso zstd
corepack enable
corepack prepare pnpm@10.15.0 --activate
rustup toolchain install 1.93.0 --profile minimal --component clippy rustfmt

missing=0
for tool in cargo pnpm mkosi xorriso qemu-system-x86_64; do command -v "$tool" >/dev/null || { echo "MISSING $tool"; missing=1; }; done
[[ -e /usr/share/OVMF/OVMF_CODE_4M.fd || -e /usr/share/OVMF/OVMF_CODE.fd ]] || { echo "MISSING OVMF firmware"; missing=1; }
if [[ "$missing" -ne 0 ]]; then echo "Builder preparation incomplete." >&2; exit 1; fi
echo "Dead Rose OS builder ready."
