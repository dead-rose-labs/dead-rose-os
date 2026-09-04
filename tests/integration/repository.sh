#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "${repo_root}"

test "$(tr -d '[:space:]' < VERSION)" = "0.1.0"
# These are literal Dockerfile ARG references, not shell expansions.
# shellcheck disable=SC2016
grep -Fq 'ARG BASE_IMAGE=ubuntu:${UBUNTU_VERSION}' os/Dockerfile
# shellcheck disable=SC2016
grep -Fq 'FROM ${BASE_IMAGE}' os/Dockerfile
# shellcheck disable=SC2016
grep -Fq 'kairos-init:${KAIROS_INIT_VERSION}' os/Dockerfile
# shellcheck disable=SC2016
grep -Fq '/kairos-init -l debug --model generic --version "${VERSION}"' os/Dockerfile
grep -Fq 'source=tests/integration/image-sanity.sh' os/Dockerfile
if grep -Eq '/kairos-init .* -s (install|init)' os/Dockerfile; then
  echo 'kairos-init must run its complete default transformation, not a partial stage' >&2
  exit 1
fi
# shellcheck disable=SC2016
grep -Fq 'auroraboot:${AURORABOOT_VERSION}' scripts/build-iso.sh
grep -Fq '/usr/share/OVMF/OVMF_CODE_4M.fd' scripts/test-qemu.sh
grep -Fq '/usr/share/OVMF/OVMF_CODE_4M.fd' scripts/test-install-qemu.sh
grep -Fq "mkdir -p \"\${repo_root}/build\"" scripts/test-qemu.sh
grep -Fq "mkdir -p \"\${repo_root}/build\"" scripts/test-install-qemu.sh
grep -Fxq 'options virtio_gpu modeset=1' os/rootfs/etc/modprobe.d/50-dead-rose-virtio-gpu.conf
grep -Fq 'multi-user.target.wants/greetd.service' os/Dockerfile
grep -Fq 'auto: false' os/cloud-config/default.yaml
grep -Fq 'auto: true' os/cloud-config/ci-install.yaml
grep -Fq '/var/lib/dead-rose' os/cloud-config/default.yaml
grep -Fq 'kairos-io/kairos/.github/workflows/reusable-factory.yaml@911d4e3fef31ba9bf85923fc846470a0a3d68e2b' .github/workflows/os-build.yml
grep -Fq 'dockerfile_path: os/Dockerfile' .github/workflows/os-build.yml
grep -Fq 'base_image: ubuntu:26.04' .github/workflows/os-build.yml
grep -Fq 'cloud_config: os/cloud-config/default.yaml' .github/workflows/os-build.yml
grep -Fq 'grype: false' .github/workflows/os-build.yml
grep -Fq 'uses: ./.github/workflows/grype-report.yml' .github/workflows/os-build.yml
grep -Fq 'anchore/scan-action@27805bf3b4e84b4a5c980df22ed233c00390a439' .github/workflows/grype-report.yml
grep -Fq 'grype-version: v0.118.0' .github/workflows/grype-report.yml
grep -Fq 'continue-on-error: true' .github/workflows/grype-report.yml
grep -Fq 'uses: ./.github/workflows/ci.yml' .github/workflows/os-build.yml
grep -Fq 'needs: ci' .github/workflows/os-build.yml
grep -Fq 'workflow_call:' .github/workflows/ci.yml

if rg -n '^  (push|pull_request):' .github/workflows/ci.yml; then
  printf 'The reusable CI workflow must not start a second workflow run\n' >&2
  exit 1
fi

if rg -n 'kairos-io/kairos-factory-action|pull_request_target|uses: [^ ]+@(main|master|latest|v[0-9])' .github/workflows; then
  printf 'A workflow uses an archived, unsafe, or moving external dependency\n' >&2
  exit 1
fi

legacy_brand='Ty''phoon|ty''phoon'
if rg -n --glob '!.agents/**' --glob '!.git/**' "${legacy_brand}" .; then
  printf 'Legacy branding remains in the rebuilt repository\n' >&2
  exit 1
fi

if rg -n 'mkosi|xorriso|grub-mkrescue|grub-install|sgdisk|\bparted\b|\bmkfs\b|Curtin|curtin' os scripts crates apps .github package.json Cargo.toml; then
  printf 'Legacy architecture remains in executable project paths\n' >&2
  exit 1
fi

if rg -n --glob '*.rs' 'Command::new\("(sh|bash)"\)|\.arg\("-c"\)' crates apps/shell/src-tauri; then
  printf 'A privileged command uses shell interpolation\n' >&2
  exit 1
fi

printf 'Repository architecture checks passed\n'
