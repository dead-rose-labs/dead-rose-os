#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mode=${1:---iso}
case "$mode" in
    --source|--iso) ;;
    *) echo "Usage: $0 [--source | --iso [path]]" >&2; exit 2 ;;
esac
while IFS= read -r -d '' script; do bash -n "$script"; done < <(find "$repo/scripts" -name '*.sh' -print0)
bash -n "$repo/archiso/profiledef.sh"
bash -n "$repo/archiso/airootfs/usr/local/bin/dead-rose-live-check"
bash -n "$repo/archiso/airootfs/usr/local/bin/install-dead-rose"
bash -n "$repo/apps/dead-rose/dead-rose"
for recipe in "$repo/packaging/"*/PKGBUILD; do bash -n "$recipe"; done
python3 "$repo/scripts/validate-profile.py"
if [[ "$mode" == --source ]]; then
    echo 'Source checks passed. ISO build and boot have NOT been checked.'
    exit 0
fi
iso=${2:-$repo/out/dead-rose-os-0.1.0-x86_64.iso}
test -s "$iso" || { echo "ISO missing: $iso" >&2; exit 1; }
command -v xorriso >/dev/null
command -v mdir >/dev/null
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
xorriso -indev "$iso" -pvd_info >"$tmp/pvd" 2>&1
grep -q 'DEADROSE_010' "$tmp/pvd"
xorriso -indev "$iso" -report_el_torito plain >"$tmp/boot" 2>&1
grep -Eq 'UEFI|EFI' "$tmp/boot"
for file in arch/x86_64/airootfs.sfs arch/boot/x86_64/vmlinuz-linux arch/boot/x86_64/initramfs-linux.img; do
    xorriso -indev "$iso" -lsdl "/$file" >"$tmp/file" 2>&1
    grep -Fq "$file" "$tmp/file"
done
# Archiso appends the ESP as a GPT partition; it is not an ISO9660 file.
sfdisk --json "$iso" > "$tmp/partitions.json"
offset=$(python3 - "$tmp/partitions.json" <<'PY'
import json, sys
table = json.load(open(sys.argv[1]))['partitiontable']
esp = [p for p in table['partitions'] if p['type'].lower() == 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b']
assert len(esp) == 1, 'Exactly one EFI system partition required'
print(esp[0]['start'] * table['sectorsize'])
PY
)
mdir -i "$iso@@$offset" ::/EFI/BOOT/BOOTX64.EFI
mdir -i "$iso@@$offset" ::/loader/entries/01-dead-rose.conf
echo "ISO structure checks passed: $iso. Run the QEMU smoke test to check boot."
