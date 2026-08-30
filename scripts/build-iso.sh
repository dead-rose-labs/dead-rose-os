#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
raw="$project_dir/build/dead-rose-os-${version}-amd64.raw"
iso="$project_dir/build/dead-rose-os-${version}-amd64.iso"
installer_root="$project_dir/build/installer-root"
installer_kernel="$installer_root.vmlinuz"
installer_initrd="$installer_root.initrd"
iso_root="$project_dir/build/iso-root"
iso_live="$iso_root/live"

fatal() {
  echo "build-iso: $*" >&2
  exit 1
}

require_regular_file() {
  local path="$1" label="$2"
  [[ -n "$path" ]] || fatal "$label variable is empty"
  [[ -f "$path" ]] || fatal "$label is not a present regular file: $path"
}

require_privileged_regular_file() {
  local path="$1" label="$2"
  [[ -n "$path" ]] || fatal "$label variable is empty"
  sudo test -f "$path" || fatal "$label is not a present regular file: $path"
}

# Ubuntu/Debian policy: /etc/shadow and /etc/gshadow must be regular files owned
# by root:shadow (gid 42) with mode 0640. systemd-sysusers creates them from
# scratch with mode 0000 during rootfs construction when no package ships them,
# so assert the final source rootfs is correct before it is packed.
assert_shadow_policy() {
  local root="${1:?image root}"

  [[ -f "$root/etc/group" ]] || fatal "$root/etc/group is missing"
  if ! LC_ALL=C awk -F: '$1 == "shadow" { print $3 }' "$root/etc/group" | grep -q '^42$'; then
    fatal "the 'shadow' group (gid 42) is missing from $root/etc/group"
  fi

  for entry in etc/shadow etc/gshadow; do
    local stat
    [[ -f "$root/$entry" ]] || fatal "$root/$entry is missing and must exist before packing"
    stat="$(stat -c '%u:%g:%a' -- "$root/$entry")"
    if [[ "$stat" != "0:42:640" ]]; then
      fatal "$entry must be owner root, group shadow (gid 42), mode 0640 before packing, got '$stat'"
    fi
  done

  echo "shadow policy OK: /etc/shadow and /etc/gshadow are root:shadow (0:42) 0640 in $root"
}

[[ -f "$raw" ]] || "$project_dir/scripts/build-os.sh"
mkdir -p "$iso_live" "$project_dir/build/logs"
cd "$project_dir"

mkosi --directory "$project_dir/os/installer" summary
corepack pnpm install --frozen-lockfile
corepack pnpm --filter @dead-rose/installer build
cargo build --release --locked -p dead-rose-installer
require_regular_file "$project_dir/target/release/dead-rose-installer" "installer binary"
require_regular_file "$project_dir/os/systemd/dead-rose-installer.service" "installer unit"
require_regular_file "$raw.zst" "compressed OS image"
require_regular_file "$raw.sha256" "OS image checksum"
sudo mkosi --directory "$project_dir/os/installer" build 2>&1 | tee "$project_dir/build/logs/mkosi-installer.log"

# Stage the installer payload without re-owning the tree: mksquashfs must
# preserve package ownership (/etc/shadow is 0640 root:shadow), so the injected
# artifacts are written as root and nothing is recursively chowned to the build
# user.
sudo install -Dm755 "$project_dir/target/release/dead-rose-installer" "$installer_root/usr/lib/dead-rose/dead-rose-installer"
sudo install -Dm644 "$project_dir/os/systemd/dead-rose-installer.service" "$installer_root/usr/lib/systemd/system/dead-rose-installer.service"
sudo mkdir -p "$installer_root/usr/lib/dead-rose-installer" "$installer_root/etc/systemd/system/graphical.target.wants"
# Preserve zero-filled regions as holes. Piping through tee materializes the
# nominal 25 GiB disk image and can exhaust the CI runner even though the raw
# image is sparse.
embedded_raw="$installer_root/usr/lib/dead-rose-installer/dead-rose-os.raw"
sudo zstd --decompress --force --sparse "$raw.zst" -o "$embedded_raw"
# zstd copies ownership metadata from its runner-owned input. Restore image
# ownership explicitly without recursively changing the mkosi root.
sudo chown 0:0 "$embedded_raw"
sudo cp "$raw.sha256" "$installer_root/usr/lib/dead-rose-installer/dead-rose-os.raw.sha256"
sudo ln -sf /usr/lib/systemd/system/dead-rose-installer.service "$installer_root/etc/systemd/system/graphical.target.wants/dead-rose-installer.service"

# systemd moves the initrd API filesystems into these directories during
# switch-root. mkosi directory images may omit empty mount points, so create
# them explicitly before the read-only SquashFS is packed.
sudo install -d -m0755 \
  "$installer_root/dev" \
  "$installer_root/proc" \
  "$installer_root/run" \
  "$installer_root/sys"
for directory in dev proc run sys; do
  sudo test -d "$installer_root/$directory" || fatal "installer root is missing switch-root mount point: /$directory"
done
if ! sudo test -e "$installer_root/sbin/init" && ! sudo test -L "$installer_root/sbin/init"; then
  fatal "installer root does not provide /sbin/init"
fi
if ! sudo test -e "$installer_root/etc/os-release" && ! sudo test -L "$installer_root/etc/os-release"; then
  fatal "installer root does not provide /etc/os-release"
fi
sudo test -s "$installer_root/usr/lib/os-release" || fatal "installer root does not provide non-empty /usr/lib/os-release"

# Fail fast on the sensitive file policy before anything gets packed: the
# source rootfs must already carry /etc/shadow and /etc/gshadow as
# root:shadow 0640, matching the runner (non-builder) Ubuntu policy.
assert_shadow_policy "$installer_root"

# Packing the live root must run with privileges: an unprivileged mksquashfs
# cannot read 0640 root:shadow files and silently packs them empty, and it
# rewrites ownership of every file to the invoking user.
rootfs_squashfs="$iso_live/rootfs.squashfs"
sudo mksquashfs "$installer_root" "$rootfs_squashfs" -comp zstd -noappend
sudo chown -- "$(id -u):$(id -g)" "$rootfs_squashfs"
echo "Packed live root filesystem: $rootfs_squashfs"
sudo "$project_dir/tests/integration/squashfs.sh" "$rootfs_squashfs" "$installer_root" "$(id -u)"

# mkosi exports the kernel and the complete, assembled initrd as split
# artifacts next to a directory image. The initrd is not guaranteed to exist
# as /boot/initrd.img-* inside the root (and may combine multiple generated
# initrds), so consume mkosi's declared outputs directly.
echo "ISO kernel: $installer_kernel"
echo "ISO initrd: $installer_initrd"
require_privileged_regular_file "$installer_kernel" "kernel"
require_privileged_regular_file "$installer_initrd" "initramfs"
# mkosi appends separately compressed microcode and kernel-module archives to
# the base initrd. Ubuntu's lsinitramfs cannot inspect more than one compressed
# cpio archive and reports the valid composite image as "unsupported format".
# The mandatory QEMU smoke test below validates the only useful contract here:
# that the complete initrd mounts the live root and starts the installer.
sudo install -m0644 "$installer_kernel" "$iso_live/vmlinuz"
sudo install -m0644 "$installer_initrd" "$iso_live/initrd"

efi_dir="$project_dir/build/efi/EFI/BOOT"
efi_binary="$efi_dir/BOOTX64.EFI"
mkdir -p "$efi_dir"
require_regular_file "$project_dir/os/installer/grub.cfg" "installer grub config"
require_regular_file "$project_dir/os/installer/grub-bootstrap.cfg" "embedded GRUB bootstrap config"
install -Dm644 "$project_dir/os/installer/grub.cfg" "$iso_root/boot/grub/grub.cfg"
grub-mkstandalone -O x86_64-efi -o "$efi_binary" "/boot/grub/grub.cfg=$project_dir/os/installer/grub-bootstrap.cfg"
echo "EFI bootloader: $efi_binary"
require_regular_file "$efi_binary" "EFI bootloader"
truncate -s 8M "$iso_root/efiboot.img"
mkfs.vfat "$iso_root/efiboot.img"
mcopy -s -i "$iso_root/efiboot.img" "$project_dir/build/efi/EFI" ::/
xorriso -as mkisofs -r -V DEAD_ROSE_INSTALLER -o "$iso" -J -joliet-long -e efiboot.img -no-emul-boot -isohybrid-gpt-basdat "$iso_root" 2>&1 | tee "$project_dir/build/logs/xorriso.log"
sudo "$project_dir/tests/integration/installer-iso.sh" "$iso" "$iso_root" "$installer_root"
sha256sum "$iso" > "$iso.sha256"
