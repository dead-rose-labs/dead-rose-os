#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:-"${repo_root}/artifacts"}

iso_count=0
iso=""
while IFS= read -r candidate; do
  iso=$candidate
  ((iso_count += 1))
done < <(find "${artifact_dir}" -type f -name '*.iso' -print)

if (( iso_count != 1 )); then
  printf 'Expected exactly one Factory ISO, found %d:\n' "${iso_count}" >&2
  find "${artifact_dir}" -maxdepth 3 -type f -print >&2
  exit 1
fi

checksum="${iso}.sha256"
if [[ ! -s "${checksum}" ]]; then
  printf 'Missing checksum for Factory ISO: %s\n' "${checksum}" >&2
  exit 1
fi

(
  cd "${repo_root}"
  sha256sum --check "${checksum}"
)

iso=$(realpath "${iso}")
printf 'Factory ISO verified: %s\n' "${iso}"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'iso=%s\n' "${iso}" >> "${GITHUB_OUTPUT}"
fi
