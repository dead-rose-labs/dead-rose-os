#!/usr/bin/env bash
set -euo pipefail

iso="${1:?usage: iso-hybrid.sh ISO}"
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  echo "hybrid ISO check: $*" >&2
  exit 1
}

[[ -s "$iso" ]] || fail "ISO is missing or empty: $iso"
for tool in fdisk mdir xorriso; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is required"
done

runtime_dir="$(mktemp -d)"
cleanup() {
  rm -rf -- "$runtime_dir"
}
trap cleanup EXIT

report_dir="${DEAD_ROSE_ISO_REPORT_DIR:-$project_dir/build/logs}"
mkdir -p "$report_dir"
fdisk_report="$report_dir/iso-fdisk.log"
eltorito_report="$report_dir/iso-el-torito.log"
system_area_report="$report_dir/iso-system-area.log"

LC_ALL=C fdisk -l "$iso" | tee "$fdisk_report"
xorriso -indev "$iso" -report_el_torito as_mkisofs 2>&1 | tee "$eltorito_report"
xorriso -indev "$iso" -report_system_area plain 2>&1 | tee "$system_area_report"

grep -Fq 'Disklabel type: gpt' "$fdisk_report" || fail "fdisk does not report a GPT"
grep -Fq 'EFI System' "$fdisk_report" || fail "fdisk does not report an EFI System Partition"
grep -Eq 'System area summary:.*MBR.*GPT' "$system_area_report" || fail "xorriso does not report both MBR and GPT metadata"
grep -Fq 'GPT type GUID' "$system_area_report" || fail "xorriso does not report GPT partition entries"
grep -Eq 'El Torito boot img[[:space:]]*:.*UEFI' "$system_area_report" "$eltorito_report" \
  || grep -Eq -- "-e[[:space:]]+'?--interval:appended_partition_" "$eltorito_report" \
  || fail "xorriso does not report a UEFI El Torito boot image"

mbr_type="$(od -An -tx1 -j 450 -N 1 "$iso" | tr -d '[:space:]')"
mbr_signature="$(od -An -tx1 -j 510 -N 2 "$iso" | tr -d '[:space:]')"
gpt_signature="$(dd if="$iso" bs=1 skip=512 count=8 status=none)"
iso_size="$(stat -c %s "$iso")"
(( iso_size % 512 == 0 )) || fail "ISO size is not aligned to a 512-byte disk sector"
backup_gpt_signature="$(dd if="$iso" bs=1 skip=$((iso_size - 512)) count=8 status=none)"
[[ "$mbr_type" == ee ]] || fail "protective MBR partition type is 0x${mbr_type:-missing}, expected 0xee"
[[ "$mbr_signature" == 55aa ]] || fail "protective MBR signature is invalid"
[[ "$gpt_signature" == "EFI PART" ]] || fail "primary GPT header is missing"
[[ "$backup_gpt_signature" == "EFI PART" ]] || fail "backup GPT header is missing"

efi_extent="$(
  awk '$1 == "GPT" && $2 == "start" && $3 == "and" && $4 == "size" && $5 == ":" && $6 == "2" {
    print $7, $8
    exit
  }' "$system_area_report"
)"
[[ -n "$efi_extent" ]] || fail "could not locate the EFI System Partition extents"
read -r efi_start efi_sectors <<<"$efi_extent"
[[ "$efi_start" =~ ^[0-9]+$ && "$efi_sectors" =~ ^[0-9]+$ ]] \
  || fail "could not locate the EFI System Partition extents"
efi_partition="$runtime_dir/efi-system-partition.img"
dd if="$iso" of="$efi_partition" bs=512 skip="$efi_start" count="$efi_sectors" status=none \
  || fail "could not extract the EFI System Partition by its GPT extents"
[[ -s "$efi_partition" ]] || fail "extracted EFI System Partition is empty"
mdir -i "$efi_partition" ::/EFI/BOOT/BOOTX64.EFI >/dev/null \
  || fail "appended EFI System Partition does not contain EFI/BOOT/BOOTX64.EFI"

listing="$(xorriso -indev "$iso" -find / -maxdepth 3 2>&1)" || fail "could not inspect ISO boot files"
grep -Fq '/live/vmlinuz' <<<"$listing" || fail "kernel is missing from the ISO filesystem"
grep -Fq '/live/initrd' <<<"$listing" || fail "initrd is missing from the ISO filesystem"
grep -Fq '/EFI/BOOT/BOOTX64.EFI' <<<"$listing" || fail "ISO9660 fallback EFI/BOOT/BOOTX64.EFI is missing"

echo "hybrid ISO check: OK - ISO9660, UEFI El Torito, protective MBR, GPT and appended ESP are valid"
