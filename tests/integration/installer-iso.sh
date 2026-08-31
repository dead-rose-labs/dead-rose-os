#!/usr/bin/env bash
set -euo pipefail

iso="${1:?usage: installer-iso.sh ISO ISO_ROOT INSTALLER_ROOT}"
iso_root="${2:?usage: installer-iso.sh ISO ISO_ROOT INSTALLER_ROOT}"
installer_root="${3:?usage: installer-iso.sh ISO ISO_ROOT INSTALLER_ROOT}"

fail() {
  echo "installer ISO check: $*" >&2
  exit 1
}

[[ -s "$iso" ]] || fail "ISO is missing or empty: $iso"
command -v xorriso >/dev/null 2>&1 || fail "xorriso is required"
command -v mdir >/dev/null 2>&1 || fail "mdir is required"
command -v unsquashfs >/dev/null 2>&1 || fail "unsquashfs is required"

listing="$(xorriso -indev "$iso" -find / -maxdepth 3 2>&1)" || fail "could not list ISO contents"
for path in /live/vmlinuz /live/initrd /live/rootfs.squashfs /efiboot.img /boot/grub/grub.cfg; do
  grep -Fq "$path" <<<"$listing" || fail "ISO is missing $path"
done

pvd="$(xorriso -indev "$iso" -pvd_info 2>&1)" || fail "could not read ISO volume metadata"
# xorriso has emitted both `Volume Id : LABEL` and
# `Volume id : 'LABEL'` across releases. Match the field itself while allowing
# the optional quotes instead of depending on one presentation format.
grep -Eq "^[[:space:]]*Volume [Ii]d[[:space:]]*:[[:space:]]*'?DEAD_ROSE_INSTALLER'?[[:space:]]*$" <<<"$pvd" || fail "ISO volume label is not DEAD_ROSE_INSTALLER"

efi_image="$iso_root/efiboot.img"
[[ -s "$efi_image" ]] || fail "EFI boot image is missing or empty"
mdir -i "$efi_image" ::/EFI/BOOT/BOOTX64.EFI >/dev/null || fail "EFI image does not contain BOOTX64.EFI"

grub_config="$iso_root/boot/grub/grub.cfg"
[[ -s "$grub_config" ]] || fail "external GRUB config is missing"
grep -Fq 'search --no-floppy --label DEAD_ROSE_INSTALLER --set=root' "$grub_config" || fail "GRUB does not search by ISO label"
grep -Fq 'menuentry "Dead Rose OS Installer"' "$grub_config" || fail "GRUB installer menu entry is missing"

rootfs="$iso_root/live/rootfs.squashfs"
unsquashfs -s "$rootfs" >/dev/null || fail "rootfs.squashfs is not readable"
[[ -x "$installer_root/usr/bin/cage" ]] || fail "Cage is missing from installer root"
[[ -x "$installer_root/usr/sbin/greetd" ]] || fail "greetd is missing from installer root"
[[ -x "$installer_root/usr/bin/curtin" ]] || fail "pinned Curtin runtime is missing from installer root"
[[ "$(stat -c '%u:%g' "$installer_root/usr/bin/curtin")" == "0:0" ]] || fail "Curtin runtime is not owned by root"
[[ -x "$installer_root/usr/lib/curtin/helpers/partition" ]] || fail "Curtin partition helper is not executable"
grep -Fq "'dd-zst': '| zstd --decompress --stdout'" "$installer_root/usr/lib/python3/dist-packages/curtin/commands/block_meta.py" || fail "Curtin zstd image support is missing"
[[ -s "$installer_root/usr/lib/dead-rose-installer/dead-rose-os.raw.zst" ]] || fail "compressed installer payload is missing"
[[ -s "$installer_root/usr/lib/dead-rose-installer/dead-rose-os.raw.zst.sha256" ]] || fail "compressed installer payload checksum is missing"
[[ ! -e "$installer_root/usr/lib/dead-rose-installer/dead-rose-os.raw" ]] || fail "expanded installer payload must not be embedded"
[[ -x "$installer_root/usr/lib/dead-rose/dead-rose-installer" ]] || fail "installer binary is missing from installer root"
[[ -x "$installer_root/usr/lib/dead-rose/dead-rose-installer-agent" ]] || fail "installer backend is missing from installer root"
[[ -x "$installer_root/usr/lib/dead-rose/dead-rose-session" ]] || fail "kiosk session supervisor is missing from installer root"
[[ -f "$installer_root/etc/greetd/config.toml" ]] || fail "installer greetd config is missing from installer root"
[[ -f "$installer_root/etc/pam.d/greetd" ]] || fail "greetd PAM policy is missing from installer root"
[[ -f "$installer_root/etc/pam.d/login" ]] || fail "system login PAM policy is missing from installer root"
[[ -f "$installer_root/usr/lib/systemd/system/dead-rose-installer-backend.service" ]] || fail "installer backend unit is missing from installer root"
grep -Fq 'Environment=DEAD_ROSE_PAYLOAD=/usr/lib/dead-rose-installer/dead-rose-os.raw.zst' "$installer_root/usr/lib/systemd/system/dead-rose-installer-backend.service" || fail "installer backend payload path does not name the compressed image"
installer_uid="$(awk -F: '$1 == "deadrose-installer" { print $3 }' "$installer_root/etc/passwd")"
[[ -n "$installer_uid" ]] || fail "deadrose-installer uid is missing"
[[ "$(awk -F: '$1 == "deadrose-installer" { print $6 }' "$installer_root/etc/passwd")" == "/var/lib/dead-rose-installer" ]] || fail "deadrose-installer home is invalid"
[[ "$(stat -c '%u:%a' "$installer_root/var/lib/dead-rose-installer")" == "$installer_uid:750" ]] || fail "installer home ownership or mode is invalid"
grep -Fq 'user = "deadrose-installer"' "$installer_root/etc/greetd/config.toml" || fail "installer UI session is not assigned to deadrose-installer"
grep -Fxq '@include login' "$installer_root/etc/pam.d/greetd" || fail "greetd PAM policy does not include the system login policy"

echo "installer ISO check: OK - UEFI, GRUB, live artifacts, greetd, Cage, unprivileged UI and backend are present"
