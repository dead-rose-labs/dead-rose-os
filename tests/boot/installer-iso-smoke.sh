#!/usr/bin/env bash
set -euo pipefail

iso="${1:?usage: installer-iso-smoke.sh ISO}"
[[ -s "$iso" ]] || { echo "Installer ISO not found: $iso" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "qemu-system-x86_64 is required" >&2; exit 1; }
command -v qemu-img >/dev/null || { echo "qemu-img is required" >&2; exit 1; }

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
target="$runtime_dir/target.qcow2"
installer_log="$runtime_dir/installer.log"
installed_log="$runtime_dir/installed.log"
firmware_vars="$runtime_dir/OVMF_VARS.fd"
qemu-img create -q -f qcow2 "$target" 40G
cp -- "$firmware_vars_template" "$firmware_vars"
qemu_pid=""
cleanup() {
  if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then kill "$qemu_pid" 2>/dev/null || true; wait "$qemu_pid" 2>/dev/null || true; fi
  rm -rf -- "$runtime_dir"
}
trap cleanup EXIT

qemu-system-x86_64 \
  -machine q35,accel=tcg -cpu max -m 3072 -smp 2 \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$firmware_code" \
  -drive "if=pflash,format=raw,unit=1,file=$firmware_vars" \
  -cdrom "$iso" -boot order=d,menu=off \
  -drive "if=none,id=target,format=qcow2,file=$target" \
  -device virtio-blk-pci,drive=target,serial=deadrose-smoke \
  -device virtio-vga -display none -serial stdio -no-reboot -no-shutdown >"$installer_log" 2>&1 &
qemu_pid="$!"

for _ in {1..1200}; do
  if rg -q 'DEAD_ROSE_INSTALL_COMPLETE' "$installer_log"; then break; fi
  if rg -q 'installer backend failed:' "$installer_log"; then
    echo "installer boot smoke: privileged backend reported failure" >&2
    tail -n 300 "$installer_log" >&2
    exit 1
  fi
  if ! kill -0 "$qemu_pid" 2>/dev/null; then
    echo "installer boot smoke: QEMU exited before installation completed" >&2
    tail -n 300 "$installer_log" >&2
    exit 1
  fi
  sleep 1
done
rg -q 'DEAD_ROSE_INSTALLER_UI_READY' "$installer_log" || { echo "installer UI never became ready" >&2; tail -n 300 "$installer_log" >&2; exit 1; }
rg -q 'DEAD_ROSE_INSTALL_COMPLETE' "$installer_log" || { echo "installation timed out" >&2; tail -n 300 "$installer_log" >&2; exit 1; }
kill "$qemu_pid" 2>/dev/null || true
wait "$qemu_pid" 2>/dev/null || true
qemu_pid=""

cp -- "$firmware_vars_template" "$firmware_vars"
qemu-system-x86_64 \
  -machine q35,accel=tcg -cpu max -m 2048 -smp 2 \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$firmware_code" \
  -drive "if=pflash,format=raw,unit=1,file=$firmware_vars" \
  -drive "if=none,id=target,format=qcow2,file=$target" \
  -device virtio-blk-pci,drive=target,serial=deadrose-smoke -boot order=c,menu=off \
  -device virtio-vga -display none -serial stdio -no-reboot -no-shutdown >"$installed_log" 2>&1 &
qemu_pid="$!"

for _ in {1..360}; do
  if rg -q 'DEAD_ROSE_SHELL_READY' "$installed_log"; then
    echo "installer boot smoke: OK - ISO UI, curtin install and installed unprivileged shell reached"
    exit 0
  fi
  if ! kill -0 "$qemu_pid" 2>/dev/null; then
    echo "installer boot smoke: installed system exited before shell readiness" >&2
    tail -n 300 "$installed_log" >&2
    exit 1
  fi
  sleep 1
done

echo "installer boot smoke: installed system did not reach Dead Rose shell" >&2
tail -n 300 "$installed_log" >&2
exit 1
