#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
iso="$project_dir/build/dead-rose-os-${version}-amd64.iso"
target="$project_dir/build/installer-target.qcow2"
[[ -f "$iso" ]] || { echo "Build the ISO first with ./dr iso" >&2; exit 1; }
if [[ "${1:-}" == "--smoke" ]]; then
  exec "$project_dir/tests/boot/installer-iso-smoke.sh" "$iso"
fi
if [[ "$#" -ne 0 ]]; then
  echo "usage: ./dr installer-vm [--smoke]" >&2
  exit 2
fi
[[ -f "$target" ]] || qemu-img create -f qcow2 "$target" 48G
firmware="/usr/share/OVMF/OVMF_CODE_4M.fd"
vars_template="/usr/share/OVMF/OVMF_VARS_4M.fd"
if [[ ! -f "$firmware" || ! -f "$vars_template" ]]; then
  firmware="/usr/share/OVMF/OVMF_CODE.fd"
  vars_template="/usr/share/OVMF/OVMF_VARS.fd"
fi
[[ -f "$firmware" && -f "$vars_template" ]] || { echo "OVMF firmware is missing; run ./dr bootstrap" >&2; exit 1; }
vars="$project_dir/build/ovmf-installer-vars.fd"
[[ -f "$vars" ]] || cp -- "$vars_template" "$vars"
accel="tcg"; [[ -e /dev/kvm ]] && accel="kvm"
exec qemu-system-x86_64 -machine "q35,accel=$accel" -cpu max -m 4096 -smp 4 \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$firmware" \
  -drive "if=pflash,format=raw,unit=1,file=$vars" \
  -cdrom "$iso" -drive "if=none,id=target,format=qcow2,file=$target" \
  -device "virtio-blk-pci,drive=target,serial=deadrose-target" \
  -boot d -display gtk
