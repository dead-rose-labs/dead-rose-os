#!/usr/bin/env bash
set -euo pipefail

image="${1:?usage: smoke.sh IMAGE}"
[[ -s "$image" ]] || { echo "Image not found: $image" >&2; exit 1; }
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

runtime_dir="$(mktemp -d)"
log="$runtime_dir/qemu.log"
firmware_vars="$runtime_dir/OVMF_VARS.fd"
cp -- "$firmware_vars_template" "$firmware_vars"
qemu_pid=""
cleanup() {
  if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then kill "$qemu_pid" 2>/dev/null || true; wait "$qemu_pid" 2>/dev/null || true; fi
  rm -rf -- "$runtime_dir"
}
trap cleanup EXIT

qemu-system-x86_64 \
  -machine q35,accel=tcg -cpu max -m 2048 -smp 2 \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$firmware_code" \
  -drive "if=pflash,format=raw,unit=1,file=$firmware_vars" \
  -drive "format=raw,file=$image" -boot order=c,menu=off \
  -device virtio-vga -display none -serial stdio -no-reboot -no-shutdown >"$log" 2>&1 &
qemu_pid="$!"

for _ in {1..360}; do
  if rg -q 'DEAD_ROSE_SHELL_READY' "$log"; then
    echo "installed boot smoke: OK - greetd, Cage and unprivileged Dead Rose shell are alive"
    exit 0
  fi
  if ! kill -0 "$qemu_pid" 2>/dev/null; then
    echo "installed boot smoke: QEMU exited before the shell became ready" >&2
    tail -n 250 "$log" >&2
    exit 1
  fi
  sleep 1
done

echo "installed boot smoke: timed out waiting for DEAD_ROSE_SHELL_READY" >&2
tail -n 250 "$log" >&2
exit 1
