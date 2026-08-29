#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
raw="$project_dir/build/dead-rose-os-${version}-amd64.raw"
iso="$project_dir/build/dead-rose-os-${version}-amd64.iso"
[[ -f "$raw" ]] || "$project_dir/scripts/build-os.sh"
mkdir -p "$project_dir/build/iso-root/live" "$project_dir/build/logs"
cd "$project_dir"
mkosi --directory "$project_dir/os/installer" summary
corepack pnpm install --frozen-lockfile
corepack pnpm --filter @dead-rose/installer build
cargo build --release --locked -p dead-rose-installer
mkosi --directory "$project_dir/os/installer" build 2>&1 | tee "$project_dir/build/logs/mkosi-installer.log"
install -Dm755 "$project_dir/target/release/dead-rose-installer" "$project_dir/build/installer-root/usr/lib/dead-rose/dead-rose-installer"
install -Dm644 "$project_dir/os/systemd/dead-rose-installer.service" "$project_dir/build/installer-root/usr/lib/systemd/system/dead-rose-installer.service"
mkdir -p "$project_dir/build/installer-root/usr/lib/dead-rose-installer" "$project_dir/build/installer-root/etc/systemd/system/graphical.target.wants"
zstd -dc "$raw.zst" > "$project_dir/build/installer-root/usr/lib/dead-rose-installer/dead-rose-os.raw"
cp "$raw.sha256" "$project_dir/build/installer-root/usr/lib/dead-rose-installer/dead-rose-os.raw.sha256"
ln -sf /usr/lib/systemd/system/dead-rose-installer.service "$project_dir/build/installer-root/etc/systemd/system/graphical.target.wants/dead-rose-installer.service"
mksquashfs "$project_dir/build/installer-root" "$project_dir/build/iso-root/live/rootfs.squashfs" -comp zstd -noappend
kernel="$(find "$project_dir/build/installer-root/boot" -name 'vmlinuz-*' -type f | sort | tail -n 1)"
initrd="$(find "$project_dir/build/installer-root/boot" -name 'initrd.img-*' -type f | sort | tail -n 1)"
cp "$kernel" "$project_dir/build/iso-root/live/vmlinuz"
cp "$initrd" "$project_dir/build/iso-root/live/initrd"
truncate -s 8M "$project_dir/build/iso-root/efiboot.img"
mkfs.vfat "$project_dir/build/iso-root/efiboot.img"
mkdir -p "$project_dir/build/efi/EFI/BOOT"
grub-mkstandalone -O x86_64-efi -o "$project_dir/build/efi/EFI/BOOT/BOOTX64.EFI" "boot/grub/grub.cfg=$project_dir/os/installer/grub.cfg"
mcopy -s -i "$project_dir/build/iso-root/efiboot.img" "$project_dir/build/efi/EFI" ::/
xorriso -as mkisofs -r -V DEAD_ROSE_INSTALLER -o "$iso" -J -joliet-long -e efiboot.img -no-emul-boot -isohybrid-gpt-basdat "$project_dir/build/iso-root" 2>&1 | tee "$project_dir/build/logs/xorriso.log"
sha256sum "$iso" > "$iso.sha256"
