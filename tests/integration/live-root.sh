#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
helper="$project_dir/os/installer/mkosi.initrd.extra/usr/lib/dead-rose-initrd/mount-live-root"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

media_device="$tmp/media-device"
media_mount="$tmp/media"
root_mount="$tmp/sysroot"
mkdir -p "$media_mount/live"
: > "$media_device"
: > "$media_mount/live/rootfs.squashfs"

udevadm() {
  return 0
}

mount() {
  local target="${@: -1}"
  if [[ "$*" == *" -t squashfs "* ]]; then
    mkdir -p "$target/usr/lib/systemd"
    : > "$target/usr/lib/systemd/systemd"
    chmod 0755 "$target/usr/lib/systemd/systemd"
  fi
}

export -f udevadm mount
output="$(
  DEAD_ROSE_MEDIA_DEVICE="$media_device" \
  DEAD_ROSE_MEDIA_MOUNT="$media_mount" \
  DEAD_ROSE_ROOT_MOUNT="$root_mount" \
  DEAD_ROSE_MEDIA_WAIT_SECONDS=1 \
  bash "$helper"
)"
grep -Fq 'dead-rose-live-root: live root mounted successfully' <<<"$output"
[[ -x "$root_mount/usr/lib/systemd/systemd" ]]

echo "live-root integration check: OK"
