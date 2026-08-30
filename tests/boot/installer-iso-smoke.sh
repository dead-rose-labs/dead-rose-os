#!/usr/bin/env bash
set -euo pipefail

iso="${1:?usage: installer-iso-smoke.sh ISO}"
[[ -s "$iso" ]] || { echo "Installer ISO not found: $iso" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "qemu-system-x86_64 is required" >&2; exit 1; }

firmware_code=""
firmware_vars_template=""
for pair in \
  /usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd \
  /usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd \
  /usr/share/edk2/x64/OVMF_CODE.fd:/usr/share/edk2/x64/OVMF_VARS.fd; do
  code="${pair%%:*}"
  vars="${pair#*:}"
  if [[ -f "$code" && -f "$vars" ]]; then
    firmware_code="$code"
    firmware_vars_template="$vars"
    break
  fi
done
[[ -n "$firmware_code" ]] || { echo "A matching OVMF CODE/VARS firmware pair was not found" >&2; exit 1; }

runtime_dir="$(mktemp -d)"
log="$runtime_dir/qemu.log"
serial_input="$runtime_dir/serial.in"
firmware_vars="$runtime_dir/OVMF_VARS.fd"
cp -- "$firmware_vars_template" "$firmware_vars"
mkfifo "$serial_input"
# Open both ends before QEMU so neither side blocks while the process starts.
exec 4<>"$serial_input"
qemu_pid=""
monitor_port=$((23000 + ($$ % 1000)))
cleanup() {
  if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
  fi
  exec 4>&-
  rm -rf -- "$runtime_dir"
}
trap cleanup EXIT

qemu-system-x86_64 \
  -machine q35,accel=tcg \
  -cpu max \
  -m 2048 \
  -smp 2 \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$firmware_code" \
  -drive "if=pflash,format=raw,unit=1,file=$firmware_vars" \
  -cdrom "$iso" \
  -boot order=d,menu=off \
  -device virtio-vga \
  -display none \
  -serial stdio \
  -monitor "tcp:127.0.0.1:${monitor_port},server=on,wait=off" \
  -no-reboot \
  -no-shutdown <"$serial_input" >"$log" 2>&1 &
qemu_pid="$!"

grub_seen=0
verbose_selected=0
root_seen=0
installer_seen=0
emergency_seen=0
for _ in {1..240}; do
  if rg -q 'Dead Rose OS Installer' "$log"; then grub_seen=1; fi
  if [[ "$grub_seen" -eq 1 && "$verbose_selected" -eq 0 ]]; then
    if exec 3<>"/dev/tcp/127.0.0.1/${monitor_port}"; then
      printf 'sendkey down\nsendkey ret\n' >&3
      exec 3>&-
      verbose_selected=1
    fi
  fi
  if rg -q 'dead-rose-live-root: live root mount validation completed successfully' "$log"; then root_seen=1; fi
  if rg -q 'Started .*Dead Rose OS Installer|Started dead-rose-installer\.service' "$log"; then installer_seen=1; fi

  if [[ "$emergency_seen" -eq 0 ]] && rg -q 'Press Enter for system maintenance' "$log"; then
    emergency_seen=1
    printf '\n' >&4
    sleep 2
    printf '%s\n' \
      'systemctl status initrd-switch-root.service --no-pager -l' \
      'systemctl status sysroot.mount run-dead\\x2drose\\x2diso.mount run-dead\\x2drose\\x2droot\\x2dro.mount run-dead\\x2drose\\x2droot\\x2drw.mount --no-pager -l || true' \
      'systemctl cat dead-rose-live-root.service initrd-switch-root.target --no-pager || true' \
      'systemctl list-dependencies initrd-switch-root.target --no-pager --all' \
      'journalctl -b -u initrd-switch-root.service --no-pager -o cat' \
      'ls -l /usr/lib/dead-rose-initrd/mount-live-root /usr/lib/systemd/system/sysroot.mount /usr/lib/systemd/system/run-dead\\x2drose\\x2diso.mount || true' \
      'lsblk -o NAME,TYPE,FSTYPE,LABEL,MODEL || true' \
      'ls -l /dev/disk/by-label /dev/sr* || true' \
      'cat /proc/modules' \
      'findmnt --mountpoint /usr || true' \
      'findmnt --mountpoint /sysroot || true' \
      'findmnt --mountpoint /run/dead-rose-iso || true' \
      'findmnt --mountpoint /run/dead-rose-root-ro || true' \
      'findmnt --mountpoint /run/dead-rose-root-rw || true' \
      'ls -ld /sysroot /sysroot/dev /sysroot/proc /sysroot/run /sysroot/sys' \
      'ls -l /sysroot/etc/os-release /sysroot/usr/lib/os-release /sysroot/sbin/init /sysroot/usr/sbin/init' >&4
    sleep 5
    echo "installer boot smoke: emergency mode reached; switch-root diagnostics follow" >&2
    tail -n 300 "$log" >&2
    exit 1
  fi

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
