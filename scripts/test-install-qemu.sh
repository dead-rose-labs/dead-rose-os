#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(tr -d '[:space:]' < "${repo_root}/VERSION")
iso="${repo_root}/build/dead-rose-os-${version}-amd64-ci.iso"
disk="${repo_root}/build/dead-rose-install.qcow2"
log="${repo_root}/build/qemu-install.log"

for candidate in /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2/x64/OVMF_CODE.fd /opt/homebrew/share/qemu/edk2-x86_64-code.fd; do
  if [[ -f "${candidate}" ]]; then ovmf="${candidate}"; break; fi
done
: "${ovmf:?OVMF firmware was not found}"
test -s "${iso}"
qemu-img create -f qcow2 "${disk}" 40G
rm -f "${log}"

qemu-system-x86_64 -machine q35 -m 4096 -smp 2 -cpu max \
  -drive "if=pflash,format=raw,readonly=on,file=${ovmf}" \
  -drive "file=${disk},if=virtio,format=qcow2" \
  -cdrom "${iso}" -boot d -nic user,model=virtio-net-pci \
  -device virtio-vga -display none -serial "file:${log}" -no-reboot &
install_pid=$!

deadline=$((SECONDS + 900))
while kill -0 "${install_pid}" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    kill "${install_pid}"
    printf 'Timed out waiting for Kairos installation\n' >&2
    tail -150 "${log}" >&2 || true
    exit 1
  fi
  sleep 2
done
wait "${install_pid}"

boot_installed() {
  local expected=$1
  local boot_log=$2
  rm -f "${boot_log}"
  qemu-system-x86_64 -machine q35 -m 4096 -smp 2 -cpu max \
    -drive "if=pflash,format=raw,readonly=on,file=${ovmf}" \
    -drive "file=${disk},if=virtio,format=qcow2" \
    -boot c -nic user,model=virtio-net-pci \
    -device virtio-vga -display none -serial "file:${boot_log}" -no-reboot &
  local boot_pid=$!
  local boot_deadline=$((SECONDS + 360))
  while (( SECONDS < boot_deadline )); do
    if [[ -f "${boot_log}" ]] && grep -Fq "${expected}" "${boot_log}"; then
      kill "${boot_pid}"
      wait "${boot_pid}" 2>/dev/null || true
      return 0
    fi
    if ! kill -0 "${boot_pid}" 2>/dev/null; then
      tail -150 "${boot_log}" >&2 || true
      return 1
    fi
    sleep 2
  done
  kill "${boot_pid}" 2>/dev/null || true
  tail -150 "${boot_log}" >&2 || true
  return 1
}

boot_installed "DEAD_ROSE_UI_READY mode=first_boot" "${repo_root}/build/qemu-installed-first.log"
boot_installed "DEAD_ROSE_PERSISTENCE_OK" "${repo_root}/build/qemu-installed-second.log"
printf 'Installed boot and persistence checks passed\n'
