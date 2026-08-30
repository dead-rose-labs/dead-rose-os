#!/usr/bin/env bash
set -euo pipefail

squashfs="${1:?usage: squashfs.sh SQUASHFS SOURCE_ROOT BUILDER_UID}"
source_root="${2:?usage: squashfs.sh SQUASHFS SOURCE_ROOT BUILDER_UID}"
builder_uid="${3:?usage: squashfs.sh SQUASHFS SOURCE_ROOT BUILDER_UID}"

fail() {
  echo "squashfs check: $*" >&2
  ok=0
}

[[ -f "$squashfs" ]] || { echo "squashfs check: squashfs not found: $squashfs" >&2; exit 1; }
[[ -d "$source_root" ]] || { echo "squashfs check: source root not found: $source_root" >&2; exit 1; }
command -v unsquashfs >/dev/null 2>&1 || { echo "squashfs check: unsquashfs is required (install squashfs-tools)" >&2; exit 1; }

workdir="$(mktemp -d)"
trap 'rm -rf -- "$workdir"' EXIT
listing="$workdir/listing.txt"
builder_owned="$workdir/builder-owned.txt"

# -lln prints numeric uid/gid (mode uid/gid size date time path), so ownership
# checks do not depend on the inspecting host's user/group name mapping.
unsquashfs -s "$squashfs" >/dev/null || { echo "squashfs check: not a readable squashfs: $squashfs" >&2; exit 1; }
unsquashfs -lln "$squashfs" > "$listing" || { echo "squashfs check: unsquashfs -lln is required (squashfs-tools 4.5+) to inspect numeric ownership" >&2; exit 1; }

ok=1

# systemd switch-root moves the initrd's API filesystems onto these paths. An
# empty directory can disappear from a generated directory image, so verify the
# paths survived packing into the immutable live root.
for directory in dev proc run sys; do
  grep -Eq " squashfs-root/$directory/?$" "$listing" || fail "squashfs is missing switch-root mount point /$directory"
done
grep -Eq ' squashfs-root/sbin/init( -> .*)?$' "$listing" || fail "squashfs is missing /sbin/init"
grep -Eq ' squashfs-root/etc/os-release( -> .*)?$' "$listing" || fail "squashfs is missing /etc/os-release"
grep -Eq ' squashfs-root/usr/lib/os-release$' "$listing" || fail "squashfs is missing /usr/lib/os-release"

# The live root must never be packed as owned by the unprivileged builder
# account (GitHub runner uid). Unprivileged packing rewrites every file to the
# invoking user, which is exactly the "Number of uids 1, runner (1001)" failure.
if awk -v owner="$builder_uid" '
    {
      split($2, ids, "/")
      if (ids[1] == owner) { print; bad = 1 }
    }
    END { exit bad ? 1 : 0 }
  ' "$listing" > "$builder_owned"; then
  :
else
  echo "squashfs check: files are owned by builder uid $builder_uid (packing was unprivileged or installer root was re-chowned):" >&2
  head -n 10 "$builder_owned" >&2
  exit 1
fi

if ! LC_ALL=C awk -F: '$1 == "shadow" { print $3 }' "$source_root/etc/group" 2>/dev/null | grep -q '^42$'; then
  echo "squashfs check: the 'shadow' group (gid 42) must exist in $source_root/etc/group" >&2
  exit 1
fi

for entry in etc/shadow etc/gshadow; do
  line="$(grep -E " squashfs-root/$entry\$" "$listing" | LC_ALL=C sort | head -n 1 || true)"
  if [[ -z "$line" ]]; then
    fail "squashfs is missing /$entry"
    continue
  fi
  set -- $line
  mode="$1"
  ids="$2"
  uid="${ids%%/*}"
  gid="${ids##*/}"
  [[ "$mode" == "-rw-r-----" ]] || fail "/$entry must keep mode 0640 (-rw-r-----), got '$mode'"
  [[ "$uid" == "0" ]] || fail "/$entry must be owned by uid 0 (root), got '$uid'"
  [[ "$gid" == "42" ]] || fail "/$entry must be owned by gid 42 (shadow), got '$gid'"
done

# The sensitive files must round-trip byte-for-byte; an unreadable source
# silently packed as empty must fail here.
for entry in etc/shadow etc/gshadow; do
  if ! unsquashfs -cat "$squashfs" "$entry" | cmp -s - "$source_root/$entry"; then
    fail "/$entry was packed empty or differs from the source image"
  fi
done

if [[ "$ok" -eq 1 ]]; then
  echo "squashfs check: OK - /etc/shadow and /etc/gshadow present, root-owned 0640, no ownership under builder uid $builder_uid"
else
  exit 1
fi
