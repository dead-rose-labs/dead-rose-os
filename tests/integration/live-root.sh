#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
helper="$project_dir/os/installer/mkosi.initrd.extra/usr/lib/dead-rose-initrd/mount-live-root"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

media_mount="$tmp/media"
root_mount="$tmp/sysroot"
mkdir -p "$media_mount/live"
: > "$media_mount/live/rootfs.squashfs"
mkdir -p "$root_mount/etc" "$root_mount/usr/lib/systemd" "$root_mount/usr/lib" "$root_mount/sbin" \
  "$root_mount/dev" "$root_mount/proc" "$root_mount/run" "$root_mount/sys"
: > "$root_mount/usr/lib/systemd/systemd"
chmod 0755 "$root_mount/usr/lib/systemd/systemd"
ln -s /usr/lib/systemd/systemd "$root_mount/sbin/init"
printf 'ID=dead-rose\n' > "$root_mount/usr/lib/os-release"
ln -s /usr/lib/os-release "$root_mount/etc/os-release"

findmnt() {
  [[ "$1" == "--mountpoint" ]]
  [[ "$2" == "$media_mount" || "$2" == "$root_mount" ]]
}

export media_mount root_mount
export -f findmnt
output="$(
  DEAD_ROSE_MEDIA_MOUNT="$media_mount" \
  DEAD_ROSE_ROOT_MOUNT="$root_mount" \
  bash "$helper"
)"
grep -Fq 'dead-rose-live-root: live root mount validation completed successfully' <<<"$output"
[[ -x "$root_mount/usr/lib/systemd/systemd" ]]
[[ -e "$root_mount/sbin/init" || -L "$root_mount/sbin/init" ]]
[[ -e "$root_mount/etc/os-release" || -L "$root_mount/etc/os-release" ]]
[[ -s "$root_mount/usr/lib/os-release" ]]
for directory in dev proc run sys; do [[ -d "$root_mount/$directory" ]]; done
[[ ! -e "$root_mount/.dead-rose-live-root-write-probe" ]]

echo "live-root integration check: OK"
