#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(tr -d '[:space:]' < "${repo_root}/VERSION")
mode="live"
iso="${repo_root}/build/dead-rose-os-${version}-amd64.iso"
disk="${repo_root}/build/dead-rose-test.qcow2"

while (( $# > 0 )); do
  case "$1" in
    live|installed)
      mode=$1
      shift
      ;;
    --iso)
      [[ $# -ge 2 ]] || { printf '%s\n' '--iso requires a value' >&2; exit 2; }
      iso=$2
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

serial_log="${repo_root}/build/qemu-${mode}.log"

find_ovmf() {
  for candidate in \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/x64/OVMF_CODE.fd \
    /opt/homebrew/share/qemu/edk2-x86_64-code.fd; do
    [[ -f "${candidate}" ]] && { printf '%s\n' "${candidate}"; return 0; }
  done
  return 1
}

ovmf=$(find_ovmf) || { printf 'OVMF firmware was not found\n' >&2; exit 1; }
test -s "${iso}"
[[ -f "${disk}" ]] || qemu-img create -f qcow2 "${disk}" 40G
rm -f "${serial_log}"

acceleration=(-accel tcg -cpu max)
if [[ "$(uname -m)" == "x86_64" && -r /dev/kvm && -w /dev/kvm ]]; then
  acceleration=(-accel kvm -cpu host)
fi

# Commas belong to QEMU option values, not to Bash array separators.
# shellcheck disable=SC2054
args=(-machine q35 -m 4096 -smp 2 "${acceleration[@]}" -drive "if=pflash,format=raw,readonly=on,file=${ovmf}" -drive "file=${disk},if=virtio,format=qcow2" -nic user,model=virtio-net-pci -device virtio-vga -display none -serial "file:${serial_log}" -no-reboot)
if [[ "${mode}" == "live" ]]; then
  args+=(-cdrom "${iso}" -boot d)
else
  args+=(-boot c)
fi

qemu-system-x86_64 "${args[@]}" &
qemu_pid=$!
trap 'kill "${qemu_pid}" 2>/dev/null || true' EXIT

deadline=$((SECONDS + 300))
expected="DEAD_ROSE_UI_READY mode="
while (( SECONDS < deadline )); do
  if [[ -f "${serial_log}" ]] && grep -Fq "${expected}" "${serial_log}"; then
    grep -F "${expected}" "${serial_log}" | tail -1
    exit 0
  fi
  if ! kill -0 "${qemu_pid}" 2>/dev/null; then
    printf 'QEMU exited before the graphical shell became ready\n' >&2
    tail -100 "${serial_log}" >&2 || true
    exit 1
  fi
  sleep 2
done
printf 'Timed out waiting for %s\n' "${expected}" >&2
tail -100 "${serial_log}" >&2 || true
exit 1
