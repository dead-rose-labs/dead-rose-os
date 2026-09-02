#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ci_mode=0
case "${1:-}" in
  "") ;;
  --ci) ci_mode=1 ;;
  -h|--help)
    echo "Usage: ./dr bootstrap [--ci]"
    echo "  --ci  Disable package-manager prompts for unattended builders."
    exit 0
    ;;
  *)
    echo "Unknown bootstrap option: $1" >&2
    exit 2
    ;;
esac

if [[ "$(uname -m)" != "x86_64" ]]; then echo "Dead Rose OS requires an amd64 builder." >&2; exit 1; fi
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "26.04" ]]; then echo "Supported builder: Ubuntu 26.04 LTS amd64." >&2; exit 1; fi

sudo apt-get update
if [[ "$ci_mode" -eq 1 ]]; then
  sudo env DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none NEEDRESTART_MODE=a \
    apt-get install -y build-essential clang cpio curl dosfstools fdisk git grub-efi-amd64-bin initramfs-tools-core jq libwebkit2gtk-4.1-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev mkosi mtools ovmf pkg-config qemu-system-x86 qemu-utils ripgrep squashfs-tools xorriso zstd
  export CI=true
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
else
  sudo apt-get install -y build-essential clang cpio curl dosfstools fdisk git grub-efi-amd64-bin initramfs-tools-core jq libwebkit2gtk-4.1-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev mkosi mtools ovmf pkg-config qemu-system-x86 qemu-utils ripgrep squashfs-tools xorriso zstd
fi

command -v corepack >/dev/null || { echo "MISSING corepack" >&2; exit 1; }
command -v rustup >/dev/null || { echo "MISSING rustup" >&2; exit 1; }
corepack pnpm --version
rustup toolchain install 1.93.0 --profile minimal --component clippy --component rustfmt --no-self-update
corepack pnpm --dir "$project_dir" install --frozen-lockfile

missing=0
for tool in cargo fdisk mkosi mdir xorriso qemu-system-x86_64 rg; do command -v "$tool" >/dev/null || { echo "MISSING $tool"; missing=1; }; done
[[ (-e /usr/share/OVMF/OVMF_CODE_4M.fd && -e /usr/share/OVMF/OVMF_VARS_4M.fd) || (-e /usr/share/OVMF/OVMF_CODE.fd && -e /usr/share/OVMF/OVMF_VARS.fd) ]] || { echo "MISSING matching OVMF CODE/VARS firmware pair"; missing=1; }
if [[ "$missing" -ne 0 ]]; then echo "Builder preparation incomplete." >&2; exit 1; fi
echo "Dead Rose OS builder ready."
