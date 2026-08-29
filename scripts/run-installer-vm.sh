#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
iso="$project_dir/build/dead-rose-os-${version}-amd64.iso"
target="$project_dir/build/installer-target.qcow2"
[[ -f "$iso" ]] || { echo "Build the ISO first with ./dr iso" >&2; exit 1; }
[[ -f "$target" ]] || qemu-img create -f qcow2 "$target" 48G
firmware="/usr/share/OVMF/OVMF_CODE_4M.fd"; [[ -f "$firmware" ]] || firmware="/usr/share/OVMF/OVMF_CODE.fd"
accel="tcg"; [[ -e /dev/kvm ]] && accel="kvm"
exec qemu-system-x86_64 -machine "q35,accel=$accel" -cpu max -m 4096 -smp 4 -drive "if=pflash,format=raw,readonly=on,file=$firmware" -cdrom "$iso" -drive "if=virtio,format=qcow2,file=$target" -boot d -display gtk
