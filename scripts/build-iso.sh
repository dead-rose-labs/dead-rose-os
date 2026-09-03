#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${repo_root}/versions.env"
version=$(tr -d '[:space:]' < "${repo_root}/VERSION")
cloud_config="${repo_root}/os/cloud-config/default.yaml"
suffix=""
if [[ "${1:-}" == "--ci" ]]; then
  cloud_config="${repo_root}/os/cloud-config/ci-install.yaml"
  suffix="-ci"
fi

mkdir -p "${repo_root}/build/auroraboot"
docker run --rm \
  --platform linux/amd64 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "${cloud_config}:/cloud-config.yaml:ro" \
  -v "${repo_root}/build/auroraboot:/tmp/auroraboot" \
  "quay.io/kairos/auroraboot:${AURORABOOT_VERSION}" \
  --set "container_image=oci:dead-rose-os:${version}" \
  --set "disable_http_server=true" \
  --set "disable_netboot=true" \
  --set "state_dir=/tmp/auroraboot" \
  --cloud-config /cloud-config.yaml

source_iso="${repo_root}/build/auroraboot/kairos.iso"
artifact="${repo_root}/build/dead-rose-os-${version}-amd64${suffix}.iso"
test -s "${source_iso}"
mv "${source_iso}" "${artifact}"
if command -v shasum >/dev/null 2>&1; then
  (cd "${repo_root}/build" && shasum -a 256 "$(basename "${artifact}")" > "$(basename "${artifact}").sha256")
else
  (cd "${repo_root}/build" && sha256sum "$(basename "${artifact}")" > "$(basename "${artifact}").sha256")
fi
printf 'Created %s\n' "${artifact}"
