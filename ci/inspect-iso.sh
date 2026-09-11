#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
stage_start inspect-iso
exec > >(tee "$ARTIFACTS/logs/inspect-iso.log") 2>&1
verify_iso_checksum
iso="$ARTIFACTS/$ISO_NAME"
size=$(stat -c %s "$iso")
(( size >= 500 * 1024 * 1024 && size <= 8 * 1024 * 1024 * 1024 )) || die "Unreasonable ISO size: $size"
inspection="$FACTORY_WORK/inspection"
[[ ! -e $inspection ]] || die 'Inspection directory must be fresh'
mkdir -p "$inspection"
xorriso -indev "$iso" -pvd_info 2>&1 | tee "$ARTIFACTS/logs/iso-metadata.txt"
grep -q "DEADROSE_${DEAD_ROSE_VERSION//./}" "$ARTIFACTS/logs/iso-metadata.txt"
xorriso -indev "$iso" -report_el_torito plain 2>&1 | tee "$ARTIFACTS/logs/iso-boot.txt"
grep -Eq 'UEFI|EFI' "$ARTIFACTS/logs/iso-boot.txt"
sfdisk --json "$iso" > "$inspection/partitions.json"
offset=$(python3 - "$inspection/partitions.json" <<'PY'
import json, sys
table = json.load(open(sys.argv[1]))['partitiontable']
assert table['label'] == 'gpt', 'GPT required'
esp = [p for p in table['partitions'] if p['type'].lower() == 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b']
assert len(esp) == 1, 'Exactly one EFI system partition required'
print(esp[0]['start'] * table['sectorsize'])
PY
)
mdir -i "$iso@@$offset" ::/EFI/BOOT/BOOTX64.EFI
mdir -i "$iso@@$offset" ::/loader/entries/01-dead-rose.conf
for file in vmlinuz-linux initramfs-linux.img; do
    xorriso -osirrox on -indev "$iso" -extract "/arch/boot/x86_64/$file" "$inspection/$file"
    test -s "$inspection/$file"
done
xorriso -osirrox on -indev "$iso" -extract /arch/pkglist.x86_64.txt "$ARTIFACTS/manifest/packages.txt"
xorriso -osirrox on -indev "$iso" -extract /arch/x86_64/airootfs.sfs "$inspection/root.sfs"
unsquashfs -d "$inspection/rootfs" "$inspection/root.sfs" \
    etc var/lib/pacman/local usr/bin/calamares usr/share/wayland-sessions \
    usr/share/plasma/look-and-feel/org.deadrose.desktop usr/share/wallpapers/DeadRose \
    usr/share/sddm/themes/deadrose usr/share/plymouth/themes/deadrose \
    usr/share/dead-rose usr/lib/calamares/modules usr/local/bin
python3 "$FACTORY_ROOT/ci/inspect-rootfs.py" "$inspection/rootfs"
pacman --dbpath "$inspection/rootfs/var/lib/pacman" -Q | sort > "$inspection/installed.txt"
sort "$ARTIFACTS/manifest/packages.txt" > "$inspection/manifest.txt"
diff -u "$inspection/manifest.txt" "$inspection/installed.txt"
python3 "$FACTORY_ROOT/ci/create-manifest.py"
stage_pass
