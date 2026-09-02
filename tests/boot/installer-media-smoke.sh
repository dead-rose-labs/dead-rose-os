#!/usr/bin/env bash
set -euo pipefail

iso="${1:?usage: installer-media-smoke.sh ISO cdrom|usb}"
mode="${2:?usage: installer-media-smoke.sh ISO cdrom|usb}"
[[ -s "$iso" ]] || { echo "Installer ISO not found: $iso" >&2; exit 1; }
case "$mode" in
  cdrom|usb) ;;
  *) echo "invalid installer media mode: $mode" >&2; exit 2 ;;
esac
command -v qemu-system-x86_64 >/dev/null || { echo "qemu-system-x86_64 is required" >&2; exit 1; }

firmware_code=""
firmware_vars_template=""
for pair in \
  /usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd \
  /usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd; do
  code="${pair%%:*}"
  vars="${pair#*:}"
  if [[ -f "$code" && -f "$vars" ]]; then firmware_code="$code"; firmware_vars_template="$vars"; break; fi
done
[[ -n "$firmware_code" ]] || { echo "OVMF firmware pair was not found" >&2; exit 1; }

qemu_accel=tcg
qemu_cpu=max
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
  qemu_accel=kvm
  qemu_cpu=host
fi

timeout_seconds="${DEAD_ROSE_MEDIA_BOOT_TIMEOUT_SECONDS:-360}"
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || { echo "invalid media boot timeout" >&2; exit 2; }
runtime_dir="$(mktemp -d)"
smoke_log_dir="${DEAD_ROSE_SMOKE_LOG_DIR:-$(pwd)/build/logs/boot}"
mkdir -p "$smoke_log_dir"
log="$smoke_log_dir/installer-${mode}-serial.log"
firmware_vars="$runtime_dir/OVMF_VARS.fd"
cp -- "$firmware_vars_template" "$firmware_vars"
qemu_pid=""
cleanup() {
  if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
  fi
  rm -rf -- "$runtime_dir"
}
trap cleanup EXIT

media_arguments=()
case "$mode" in
  cdrom)
    media_arguments=(-cdrom "$iso" -boot order=d,menu=off,strict=on)
    ;;
  usb)
    media_arguments=(
      -device qemu-xhci,id=deadrose-usb
      -drive "if=none,id=installer,format=raw,readonly=on,file=$iso"
      -device usb-storage,drive=installer,bootindex=1,bus=deadrose-usb.0
      -boot menu=off,strict=on
    )
    ;;
esac

echo "installer $mode boot smoke: using QEMU accelerator $qemu_accel"
qemu-system-x86_64 \
  -machine "q35,accel=$qemu_accel" -cpu "$qemu_cpu" -m 2048 -smp 2 \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$firmware_code" \
  -drive "if=pflash,format=raw,unit=1,file=$firmware_vars" \
  "${media_arguments[@]}" \
  -device virtio-vga -display none -serial stdio -no-reboot -no-shutdown >"$log" 2>&1 &
qemu_pid="$!"

deadline=$((SECONDS + timeout_seconds))
while (( SECONDS < deadline )); do
  if rg -q 'DEAD_ROSE_INSTALLER_UI_READY' "$log"; then
    echo "installer $mode boot smoke: OK - UEFI reached the Dead Rose installer"
    exit 0
  fi
  if rg -q 'DEAD_ROSE_SMOKE_DIAGNOSTICS_END' "$log"; then
    echo "installer $mode boot smoke: live session diagnostics reported failure" >&2
    tail -n 300 "$log" >&2
    exit 1
  fi
  if ! kill -0 "$qemu_pid" 2>/dev/null; then
    echo "installer $mode boot smoke: QEMU exited before installer readiness" >&2
    tail -n 300 "$log" >&2
    exit 1
  fi
  sleep 1
done

echo "installer $mode boot smoke: timed out waiting for installer readiness" >&2
tail -n 300 "$log" >&2
exit 1
