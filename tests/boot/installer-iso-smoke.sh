#!/usr/bin/env bash
set -euo pipefail

iso="${1:?usage: installer-iso-smoke.sh ISO}"
[[ -s "$iso" ]] || { echo "Installer ISO not found: $iso" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "qemu-system-x86_64 is required" >&2; exit 1; }

firmware=""
for candidate in \
  /usr/share/OVMF/OVMF_CODE_4M.fd \
  /usr/share/OVMF/OVMF_CODE.fd \
  /usr/share/edk2/x64/OVMF_CODE.fd; do
  if [[ -f "$candidate" ]]; then
    firmware="$candidate"
    break
  fi
done
[[ -n "$firmware" ]] || { echo "OVMF firmware was not found" >&2; exit 1; }

log="$(mktemp)"
qemu_pid=""
monitor_port=$((23000 + ($$ % 1000)))
cleanup() {
  if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
  fi
  rm -f -- "$log"
}
trap cleanup EXIT

qemu-system-x86_64 \
  -machine q35,accel=tcg \
  -cpu max \
  -m 2048 \
  -smp 2 \
  -bios "$firmware" \
  -cdrom "$iso" \
  -boot order=d,menu=off \
  -device virtio-vga \
  -display none \
  -serial stdio \
  -monitor "tcp:127.0.0.1:${monitor_port},server=on,wait=off" \
  -no-reboot \
  -no-shutdown >"$log" 2>&1 &
qemu_pid="$!"

grub_seen=0
verbose_selected=0
root_seen=0
installer_seen=0
for _ in {1..240}; do
  if rg -q 'Dead Rose OS Installer' "$log"; then grub_seen=1; fi
  if [[ "$grub_seen" -eq 1 && "$verbose_selected" -eq 0 ]]; then
    if exec 3<>"/dev/tcp/127.0.0.1/${monitor_port}"; then
      printf 'sendkey down\nsendkey ret\n' >&3
      exec 3>&-
      verbose_selected=1
    fi
  fi
  if rg -q 'dead-rose-live-root: live root mounted successfully' "$log"; then root_seen=1; fi
  if rg -q 'Started .*Dead Rose OS Installer|Started dead-rose-installer\.service' "$log"; then installer_seen=1; fi

  if [[ "$grub_seen" -eq 1 && "$root_seen" -eq 1 && "$installer_seen" -eq 1 ]]; then
    echo "installer boot smoke: OK - GRUB, live root, switch-root and installer service reached"
    exit 0
  fi
  if ! kill -0 "$qemu_pid" 2>/dev/null; then
    echo "installer boot smoke: QEMU exited before boot completed" >&2
    tail -n 200 "$log" >&2
    exit 1
  fi
  sleep 1
done

echo "installer boot smoke: timed out after 240 seconds (grub=$grub_seen verbose=$verbose_selected live_root=$root_seen installer=$installer_seen)" >&2
tail -n 200 "$log" >&2
exit 1
