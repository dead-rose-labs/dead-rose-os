#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="$project_dir/build/installer-target.qcow2"
[[ -f "$image" ]] || { echo "Install the ISO first with ./dr installer-vm" >&2; exit 1; }
firmware="/usr/share/OVMF/OVMF_CODE_4M.fd"
vars_template="/usr/share/OVMF/OVMF_VARS_4M.fd"
if [[ ! -f "$firmware" || ! -f "$vars_template" ]]; then
  firmware="/usr/share/OVMF/OVMF_CODE.fd"
  vars_template="/usr/share/OVMF/OVMF_VARS.fd"
fi
[[ -f "$firmware" && -f "$vars_template" ]] || { echo "OVMF firmware is missing; run ./dr bootstrap" >&2; exit 1; }
vars="$project_dir/build/ovmf-installed-vars.fd"
[[ -f "$vars" ]] || cp -- "$vars_template" "$vars"
accel="tcg"; [[ -e /dev/kvm ]] && accel="kvm"
[[ "$accel" == "kvm" ]] || echo "KVM unavailable; using slower TCG emulation."
exec qemu-system-x86_64 -machine "q35,accel=$accel" -cpu max -m 4096 -smp 4 \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$firmware" \
  -drive "if=pflash,format=raw,unit=1,file=$vars" \
  -drive "format=qcow2,file=$image,snapshot=on" -display gtk
