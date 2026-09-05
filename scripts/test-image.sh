#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(tr -d '[:space:]' < "${repo_root}/VERSION")
image="dead-rose-os:${version}"

while (( $# > 0 )); do
  case "$1" in
    --image)
      [[ $# -ge 2 ]] || { printf '%s\n' '--image requires a value' >&2; exit 2; }
      image=$2
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

docker run --rm \
  --entrypoint /bin/bash \
  -v "${repo_root}/tests/integration/image-sanity.sh:/tmp/image-sanity.sh:ro" \
  "${image}" /tmp/image-sanity.sh

# Inspect the final candidate OCI, not the Dockerfile or a rebuilt test image.
# Installer/agent units are materialized by Kairos at boot; their absence here
# is reported, while their bundled definitions and the agent must exist.
docker image inspect "${image}" --format 'Candidate OCI digests: {{json .RepoDigests}}'
docker run --rm -i --network none \
  --entrypoint /bin/bash \
  -v "${repo_root}/os/cloud-config/ci-install.yaml:/tmp/ci-install.yaml:ro" \
  "${image}" -s <<'SH'
set -euo pipefail
test -x /usr/bin/kairos-agent
/usr/bin/kairos-agent --version
for config in 00_datasource.yaml 02_agent.yaml 09_systemd_services.yaml 52_installer.yaml; do
  test -s "/system/oem/${config}"
  printf '\n--- /system/oem/%s ---\n' "${config}"
  cat "/system/oem/${config}"
done
find /etc/systemd/system /usr/lib/systemd/system -maxdepth 3 \
  \( -name 'kairos-*.service' -o -name 'cos-setup-*.service' \) -ls
for unit in kairos-installer.service kairos-agent.service cos-setup-fs.service cos-setup-boot.service cos-setup-network.service; do
  printf '\nOCI unit enablement: %s\n' "${unit}"
  if systemctl --root=/ is-enabled "${unit}"; then
    :
  else
    printf 'Not enabled in OCI; check runtime-generated unit in guest diagnostics\n'
  fi
done
# Record strict schema validation independently: the install command's normal
# parser warns on schema errors unless strict validation was requested. Do not
# prevent the requested runtime diagnosis by introducing a new acceptance gate.
if /usr/bin/kairos-agent validate /tmp/ci-install.yaml; then
  printf 'KAIROS_INSTALL_CONFIG_VALIDATION=PASS\n'
else
  validation_status=$?
  printf 'KAIROS_INSTALL_CONFIG_VALIDATION=FAIL exit=%s (diagnostic; install parser is non-strict)\n' "${validation_status}"
fi
SH
