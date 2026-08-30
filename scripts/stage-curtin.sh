#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${1:?usage: stage-curtin.sh INSTALLER_ROOT}"
curtin_commit="e2fc2bb9e38c7336c181567864f6b963e5c3835b"
curtin_sha256="4f6e28c53c4a780db0d02873628ca0897b9099fac0507b2a793620b2d1c55177"
archive="$project_dir/build/curtin-${curtin_commit}.tar.gz"
source_dir="$project_dir/build/curtin-${curtin_commit}"
url="https://github.com/canonical/curtin/archive/${curtin_commit}.tar.gz"

archive_is_valid() {
  [[ -f "$archive" ]] && [[ "$(sha256sum "$archive" | awk '{print $1}')" == "$curtin_sha256" ]]
}

case "$destination" in
  "$project_dir"/build/installer-root) ;;
  *) echo "stage-curtin: refusing unexpected destination: $destination" >&2; exit 1 ;;
esac

if ! archive_is_valid; then
  curl --fail --location --retry 3 --output "$archive" "$url"
fi
archive_is_valid || { echo "stage-curtin: source checksum mismatch" >&2; exit 1; }

if [[ "$source_dir" != "$project_dir/build/curtin-$curtin_commit" ]]; then
  echo "stage-curtin: refusing unsafe source directory" >&2
  exit 1
fi
find "$source_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
mkdir -p "$source_dir"
tar --extract --gzip --file "$archive" --strip-components=1 --directory "$source_dir"

run_privileged() {
  if [[ -w "$destination" ]]; then
    "$@"
  else
    sudo "$@"
  fi
}
run_privileged install -d -m0755 "$destination/usr/bin" "$destination/usr/lib/python3/dist-packages/curtin" "$destination/usr/lib/curtin/helpers"
run_privileged install -m0755 "$source_dir/bin/curtin" "$destination/usr/bin/curtin"
run_privileged cp -a "$source_dir/curtin/." "$destination/usr/lib/python3/dist-packages/curtin/"
run_privileged cp -a "$source_dir/helpers/." "$destination/usr/lib/curtin/helpers/"
run_privileged find "$destination/usr/lib/python3/dist-packages/curtin" "$destination/usr/lib/curtin/helpers" -type d -exec chmod 0755 {} +
run_privileged find "$destination/usr/lib/python3/dist-packages/curtin" "$destination/usr/lib/curtin/helpers" -type f -exec chmod 0644 {} +
run_privileged test -x "$destination/usr/bin/curtin"

echo "Staged Canonical Curtin commit $curtin_commit"
