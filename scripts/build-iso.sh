#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
raw="$project_dir/build/dead-rose-os-${version}-amd64.raw"
iso="$project_dir/build/dead-rose-os-${version}-amd64.iso"
installer_root="$project_dir/build/installer-root"
installer_kernel="$installer_root.vmlinuz"
installer_initrd="$installer_root.initrd"
initrd_extra_tree="$project_dir/os/installer/mkosi.initrd.extra"
initrd_overlay="$project_dir/build/dead-rose-installer-overlay.initrd.zst"
initrd_overlay_listing="$project_dir/build/logs/dead-rose-installer-overlay.list"
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

build_initrd_overlay() {
  local required

  [[ -d "$initrd_extra_tree" ]] || fatal "initrd extra tree is missing: $initrd_extra_tree"
  command -v cpio >/dev/null || fatal "cpio is required to assemble the installer initrd overlay"

  (
    cd "$initrd_extra_tree"
    find . -mindepth 1 -print0 \
      | LC_ALL=C sort -z \
      | cpio --null --create --format=newc --owner=+0:+0 --quiet
  ) | zstd --quiet --force --threads=0 -19 -o "$initrd_overlay"

  zstd --quiet --decompress --stdout "$initrd_overlay" \
    | cpio --list --quiet \
    | sed 's#^\./##' > "$initrd_overlay_listing"

  for required in \
    usr/lib/dead-rose-initrd/mount-live-root \
    usr/lib/systemd/system/dead-rose-initrd-ready.service \
    usr/lib/systemd/system/dead-rose-live-root.service \
    'usr/lib/systemd/system/run-dead\x2drose\x2diso.mount' \
    'usr/lib/systemd/system/run-dead\x2drose\x2droot\x2dro.mount' \
    'usr/lib/systemd/system/run-dead\x2drose\x2droot\x2drw.mount' \
    usr/lib/systemd/system/dead-rose-live-overlay-prepare.service \
    usr/lib/systemd/system/sysroot.mount \
    usr/lib/systemd/system/initrd-root-fs.target.d/dead-rose-live-root.conf \
    usr/lib/systemd/system/initrd-switch-root.target.d/dead-rose-live-root.conf; do
    grep -Fxq "$required" "$initrd_overlay_listing" \
      || fatal "installer initrd overlay is missing required path: /$required"
  done

  echo "Installer initrd overlay: $initrd_overlay"
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
for generated in "$installer_root" "$iso_root" "$project_dir/build/efi"; do
  case "$generated" in
    "$project_dir"/build/*) ;;
    *) fatal "refusing unsafe generated directory: $generated" ;;
  esac
  if [[ -d "$generated" ]]; then
    sudo find "$generated" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  fi
done
mkdir -p "$iso_live" "$project_dir/build/logs"
cd "$project_dir"

mkosi --directory "$project_dir/os/installer" summary
corepack pnpm install --frozen-lockfile
corepack pnpm --filter @dead-rose/installer build
cargo build --release --locked -p dead-rose-installer -p dead-rose-installer-agent -p dead-rose-session --bins
require_regular_file "$project_dir/target/release/dead-rose-installer" "installer binary"
require_regular_file "$project_dir/target/release/dead-rose-installer-agent" "installer backend"
require_regular_file "$project_dir/target/release/dead-rose-session" "kiosk session supervisor"
require_regular_file "$project_dir/os/systemd/dead-rose-installer-backend.service" "installer backend unit"
require_regular_file "$project_dir/os/greetd/installer.toml" "installer greetd config"
require_regular_file "$project_dir/os/pam/greetd" "greetd PAM policy"
require_regular_file "$raw.zst" "compressed OS image"
require_regular_file "$raw.sha256" "OS image checksum"
sudo mkosi --directory "$project_dir/os/installer" build 2>&1 | tee "$project_dir/build/logs/mkosi-installer.log"

# Stage the installer payload without re-owning the tree: mksquashfs must
# preserve package ownership (/etc/shadow is 0640 root:shadow), so the injected
# artifacts are written as root and nothing is recursively chowned to the build
# user.
sudo install -Dm755 "$project_dir/target/release/dead-rose-installer" "$installer_root/usr/lib/dead-rose/dead-rose-installer"
sudo install -Dm755 "$project_dir/target/release/dead-rose-installer-agent" "$installer_root/usr/lib/dead-rose/dead-rose-installer-agent"
sudo install -Dm755 "$project_dir/target/release/dead-rose-session" "$installer_root/usr/lib/dead-rose/dead-rose-session"
for binary in dead-rose-installer dead-rose-installer-agent dead-rose-session; do
  sudo chroot "$installer_root" /usr/bin/ldd "/usr/lib/dead-rose/$binary" \
    | tee "$project_dir/build/logs/ldd-$binary.log"
  if grep -q 'not found' "$project_dir/build/logs/ldd-$binary.log"; then
    fatal "$binary has unresolved runtime libraries in the installer root"
  fi
done
sudo install -Dm644 "$project_dir/os/systemd/dead-rose-installer-backend.service" "$installer_root/usr/lib/systemd/system/dead-rose-installer-backend.service"
sudo install -Dm644 "$project_dir/os/systemd/greetd-installer.conf" "$installer_root/etc/systemd/system/greetd.service.d/dead-rose.conf"
sudo install -Dm644 "$project_dir/os/greetd/installer.toml" "$installer_root/etc/greetd/config.toml"
sudo install -Dm644 "$project_dir/os/pam/greetd" "$installer_root/etc/pam.d/greetd"
sudo install -Dm644 "$project_dir/os/sysusers/dead-rose.conf" "$installer_root/usr/lib/sysusers.d/dead-rose.conf"
sudo install -Dm644 "$project_dir/os/tmpfiles/dead-rose.conf" "$installer_root/usr/lib/tmpfiles.d/dead-rose.conf"
# These definitions are injected after mkosi has assembled the directory
# image, so materialize them explicitly before the live root is packed.
sudo systemd-sysusers --root="$installer_root"
sudo systemd-tmpfiles \
  --root="$installer_root" \
  --create \
  --prefix=/var/lib/dead-rose \
  --prefix=/var/lib/dead-rose-ui \
  --prefix=/var/lib/dead-rose-installer \
  --prefix=/run/dead-rose \
  --prefix=/run/dead-rose-installer
for identity in deadrose-core deadrose-ui deadrose-installer; do
  sudo awk -F: -v name="$identity" '$1 == name { found = 1 } END { exit !found }' "$installer_root/etc/passwd" \
    || fatal "installer root is missing system user: $identity"
done
for group in deadrose-ipc deadrose-installer-ipc; do
  sudo awk -F: -v name="$group" '$1 == name { found = 1 } END { exit !found }' "$installer_root/etc/group" \
    || fatal "installer root is missing system group: $group"
done
sudo test -d "$installer_root/var/lib/dead-rose-installer" \
  || fatal "installer home directory was not materialized"
sudo install -Dm644 "$project_dir/os/mkosi.extra/etc/os-release" "$installer_root/usr/lib/os-release"
sudo install -Dm644 "$project_dir/os/plymouth/dead-rose/dead-rose.plymouth" "$installer_root/usr/share/plymouth/themes/dead-rose/dead-rose.plymouth"
sudo install -Dm644 "$project_dir/os/plymouth/dead-rose/dead-rose.script" "$installer_root/usr/share/plymouth/themes/dead-rose/dead-rose.script"
sudo install -Dm644 "$project_dir/assets/brand/dead-rose-os-logo.png" "$installer_root/usr/share/plymouth/themes/dead-rose/dead-rose-os-logo.png"
"$project_dir/scripts/stage-curtin.sh" "$installer_root"
sudo mkdir -p "$installer_root/usr/lib/dead-rose-installer" "$installer_root/etc/systemd/system/graphical.target.wants" "$installer_root/etc/systemd/system/multi-user.target.wants" "$installer_root/usr/share/plymouth/themes"
# Preserve zero-filled regions as holes. Piping through tee materializes the
# nominal 25 GiB disk image and can exhaust the CI runner even though the raw
# image is sparse.
embedded_raw="$installer_root/usr/lib/dead-rose-installer/dead-rose-os.raw"
sudo zstd --decompress --force --sparse "$raw.zst" -o "$embedded_raw"
# zstd copies ownership metadata from its runner-owned input. Restore image
# ownership explicitly without recursively changing the mkosi root.
sudo chown 0:0 "$embedded_raw"
sudo cp "$raw.sha256" "$installer_root/usr/lib/dead-rose-installer/dead-rose-os.raw.sha256"
sudo ln -sf /usr/lib/systemd/system/greetd.service "$installer_root/etc/systemd/system/graphical.target.wants/greetd.service"
sudo ln -sf /usr/lib/systemd/system/dead-rose-installer-backend.service "$installer_root/etc/systemd/system/multi-user.target.wants/dead-rose-installer-backend.service"
sudo ln -sf /usr/lib/systemd/system/graphical.target "$installer_root/etc/systemd/system/default.target"
sudo ln -sf /usr/share/plymouth/themes/dead-rose/dead-rose.plymouth "$installer_root/usr/share/plymouth/themes/default.plymouth"
if [[ "${DEAD_ROSE_TEST_MARKERS:-0}" == "1" ]]; then
  sudo install -Dm755 "$project_dir/tests/boot/assets/session-ready" "$installer_root/usr/lib/dead-rose-tests/session-ready"
  sudo install -Dm755 "$project_dir/tests/boot/assets/install-driver.py" "$installer_root/usr/lib/dead-rose-tests/install-driver.py"
  sudo install -Dm755 "$project_dir/tests/boot/assets/smoke-diagnostics" "$installer_root/usr/lib/dead-rose-tests/smoke-diagnostics"
  sudo install -Dm644 "$project_dir/tests/boot/assets/installer-session-ready.service" "$installer_root/usr/lib/systemd/system/installer-session-ready.service"
  sudo install -Dm644 "$project_dir/tests/boot/assets/install-driver.service" "$installer_root/usr/lib/systemd/system/install-driver.service"
  sudo install -Dm644 "$project_dir/tests/boot/assets/smoke-diagnostics.service" "$installer_root/usr/lib/systemd/system/dead-rose-smoke-diagnostics.service"
  sudo install -Dm644 "$project_dir/tests/boot/assets/smoke-watchdog.service" "$installer_root/usr/lib/systemd/system/dead-rose-smoke-watchdog.service"
  sudo ln -sf /usr/lib/systemd/system/installer-session-ready.service "$installer_root/etc/systemd/system/graphical.target.wants/installer-session-ready.service"
  sudo ln -sf /usr/lib/systemd/system/install-driver.service "$installer_root/etc/systemd/system/graphical.target.wants/install-driver.service"
  sudo ln -sf /usr/lib/systemd/system/dead-rose-smoke-watchdog.service "$installer_root/etc/systemd/system/multi-user.target.wants/dead-rose-smoke-watchdog.service"
fi

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
# The default-initrd ExtraTrees hook is not consistently applied by packaged
# mkosi releases. Build our initrd-only files as an explicit final archive in
# the composite initramfs instead. Linux unpacks concatenated compressed newc
# archives in order, which is also how mkosi adds microcode and kernel modules.
build_initrd_overlay
sudo install -m0644 "$installer_kernel" "$iso_live/vmlinuz"
sudo install -m0644 "$installer_initrd" "$iso_live/initrd"
sudo dd if="$initrd_overlay" of="$iso_live/initrd" oflag=append conv=notrunc status=none

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
