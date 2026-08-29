#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
image="$project_dir/build/dead-rose-os-${version}-amd64.raw"
[[ -f "$image" ]] || { echo "Build the image first with ./dr build" >&2; exit 1; }
firmware="/usr/share/OVMF/OVMF_CODE_4M.fd"; [[ -f "$firmware" ]] || firmware="/usr/share/OVMF/OVMF_CODE.fd"
accel="tcg"; [[ -e /dev/kvm ]] && accel="kvm"
[[ "$accel" == "kvm" ]] || echo "KVM unavailable; using slower TCG emulation."
exec qemu-system-x86_64 -machine "q35,accel=$accel" -cpu max -m 4096 -smp 4 -drive "if=pflash,format=raw,readonly=on,file=$firmware" -drive "format=raw,file=$image" -display gtk
