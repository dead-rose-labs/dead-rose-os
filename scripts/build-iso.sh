#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
raw="$project_dir/build/dead-rose-os-${version}-amd64.raw"
iso="$project_dir/build/dead-rose-os-${version}-amd64.iso"
installer_root="$project_dir/build/installer-root"
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

resolve_single_boot_artifact() {
  local label="$1" pattern="$2" search_root="$3"
  local -a candidates=()
  if [[ ! -d "$search_root" ]]; then
    fatal "no $label sources: directory does not exist: $search_root"
  fi
  mapfile -t candidates < <(find "$search_root" -name "$pattern" -type f | LC_ALL=C sort)
  case "${#candidates[@]}" in
    0) fatal "no $label matching '$pattern' under $search_root; install a kernel/initrd in the installer image" ;;
    1) ;;
    *)
      printf 'build-iso: %s files match %s under %s; aborting because the boot artifact is ambiguous:\n' "${#candidates[@]}" "'$pattern'" "$search_root" >&2
      printf '  %s\n' "${candidates[@]}" >&2
      exit 1
      ;;
  esac
  printf '%s\n' "${candidates[0]}"
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
zstd -dc "$raw.zst" | sudo tee "$installer_root/usr/lib/dead-rose-installer/dead-rose-os.raw" >/dev/null
sudo cp "$raw.sha256" "$installer_root/usr/lib/dead-rose-installer/dead-rose-os.raw.sha256"
sudo ln -sf /usr/lib/systemd/system/dead-rose-installer.service "$installer_root/etc/systemd/system/graphical.target.wants/dead-rose-installer.service"

# Packing the live root must run with privileges: an unprivileged mksquashfs
# cannot read 0640 root:shadow files and silently packs them empty, and it
# rewrites ownership of every file to the invoking user.
rootfs_squashfs="$iso_live/rootfs.squashfs"
sudo mksquashfs "$installer_root" "$rootfs_squashfs" -comp zstd -noappend
sudo chown -- "$(id -u):$(id -g)" "$rootfs_squashfs"
echo "Packed live root filesystem: $rootfs_squashfs"
sudo "$project_dir/tests/integration/squashfs.sh" "$rootfs_squashfs" "$installer_root" "$(id -u)"

kernel="$(resolve_single_boot_artifact kernel 'vmlinuz-*' "$installer_root/boot")"
initrd="$(resolve_single_boot_artifact initramfs 'initrd.img-*' "$installer_root/boot")"
echo "ISO kernel: $kernel"
echo "ISO initrd: $initrd"
require_regular_file "$kernel" "kernel"
require_regular_file "$initrd" "initramfs"
cp "$kernel" "$iso_live/vmlinuz"
cp "$initrd" "$iso_live/initrd"

efi_dir="$project_dir/build/efi/EFI/BOOT"
efi_binary="$efi_dir/BOOTX64.EFI"
mkdir -p "$efi_dir"
require_regular_file "$project_dir/os/installer/grub.cfg" "installer grub config"
grub-mkstandalone -O x86_64-efi -o "$efi_binary" "boot/grub/grub.cfg=$project_dir/os/installer/grub.cfg"
echo "EFI bootloader: $efi_binary"
require_regular_file "$efi_binary" "EFI bootloader"
truncate -s 8M "$iso_root/efiboot.img"
mkfs.vfat "$iso_root/efiboot.img"
mcopy -s -i "$iso_root/efiboot.img" "$project_dir/build/efi/EFI" ::/
xorriso -as mkisofs -r -V DEAD_ROSE_INSTALLER -o "$iso" -J -joliet-long -e efiboot.img -no-emul-boot -isohybrid-gpt-basdat "$iso_root" 2>&1 | tee "$project_dir/build/logs/xorriso.log"
sha256sum "$iso" > "$iso.sha256"
