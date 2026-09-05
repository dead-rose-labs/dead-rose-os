#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(tr -d '[:space:]' < "${repo_root}/VERSION")
iso="${repo_root}/build/dead-rose-os-${version}-amd64.iso"
cloud_config="${repo_root}/os/cloud-config/ci-install.yaml"
disk="${repo_root}/build/dead-rose-install.qcow2"
log="${repo_root}/build/qemu-install.log"
serial_socket="${repo_root}/build/qemu-install.serial.sock"
config_drive="${repo_root}/build/dead-rose-ci-config.iso"

while (( $# > 0 )); do
  case "$1" in
    --iso)
      [[ $# -ge 2 ]] || { printf '%s\n' '--iso requires a value' >&2; exit 2; }
      iso=$2
      shift 2
      ;;
    --config)
      [[ $# -ge 2 ]] || { printf '%s\n' '--config requires a value' >&2; exit 2; }
      cloud_config=$2
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

mkdir -p "${repo_root}/build"
for candidate in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2/x64/OVMF_CODE.fd /opt/homebrew/share/qemu/edk2-x86_64-code.fd; do
  if [[ -f "${candidate}" ]]; then ovmf="${candidate}"; break; fi
done
: "${ovmf:?OVMF firmware was not found}"
test -s "${iso}"
test -s "${cloud_config}"
command -v mkisofs >/dev/null 2>&1 || { printf 'mkisofs is required for the Kairos config drive\n' >&2; exit 1; }
command -v isoinfo >/dev/null

config_dir=$(mktemp -d)
trap 'rm -rf "${config_dir}"; if [[ -n "${install_pid:-}" ]]; then kill "${install_pid}" 2>/dev/null || true; fi' EXIT
cp "${cloud_config}" "${config_dir}/user-data"
: > "${config_dir}/meta-data"
mkisofs -quiet -output "${config_drive}" -volid cidata -joliet -rock "${config_dir}/user-data" "${config_dir}/meta-data"
# Inspect the actual ISO, including the bytes Kairos will read through Rock Ridge.
isoinfo -d -i "${config_drive}" | grep -Fx 'Volume id: cidata'
config_files=$(isoinfo -R -f -i "${config_drive}")
grep -Fx '/user-data' <<< "${config_files}"
grep -Fx '/meta-data' <<< "${config_files}"
isoinfo -R -i "${config_drive}" -x /user-data > "${config_dir}/extracted-user-data"
isoinfo -R -i "${config_drive}" -x /meta-data > "${config_dir}/extracted-meta-data"
cmp "${cloud_config}" "${config_dir}/extracted-user-data"
cmp "${config_dir}/meta-data" "${config_dir}/extracted-meta-data"
printf 'CIDATA ISO content verified byte-for-byte\n'

rm -f "${disk}"
qemu-img create -f qcow2 "${disk}" 40G
rm -f "${log}" "${serial_socket}"

acceleration=(-accel tcg -cpu max)
if [[ "$(uname -m)" == "x86_64" && -r /dev/kvm && -w /dev/kvm ]]; then
  acceleration=(-accel kvm -cpu host)
fi

qemu-system-x86_64 -machine q35 -m 4096 -smp 2 "${acceleration[@]}" \
  -drive "if=pflash,format=raw,readonly=on,file=${ovmf}" \
  -drive "file=${disk},if=virtio,format=qcow2" \
  -drive "file=${iso},media=cdrom,readonly=on" \
  -drive "file=${config_drive},media=cdrom,readonly=on" \
  -boot d -nic user,model=virtio-net-pci \
  -device virtio-vga -display none \
  -chardev "socket,id=deadrose_serial,path=${serial_socket},server=on,wait=off,logfile=${log}" \
  -serial chardev:deadrose_serial -no-reboot &
install_pid=$!

deadline=$((SECONDS + 900))
while kill -0 "${install_pid}" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    printf 'Timed out waiting for Kairos installation\n' >&2
    if ! python3 "${repo_root}/scripts/collect-qemu-diagnostics.py" "${serial_socket}" install; then
      printf 'Unable to collect Kairos installation diagnostics\n' >&2
    fi
    tail -300 "${log}" >&2 || true
    exit 1
  fi
  sleep 2
done
wait "${install_pid}"

boot_installed() {
  local expected=$1
  local boot_log=$2
  rm -f "${boot_log}"
  qemu-system-x86_64 -machine q35 -m 4096 -smp 2 "${acceleration[@]}" \
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
