#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "${repo_root}"

test "$(tr -d '[:space:]' < VERSION)" = "0.1.0"
grep -Fq 'FROM ubuntu:${UBUNTU_VERSION}' os/Dockerfile
grep -Fq 'kairos-init:${KAIROS_INIT_VERSION}' os/Dockerfile
grep -Fq 'auroraboot:${AURORABOOT_VERSION}' scripts/build-iso.sh
grep -Fq 'auto: false' os/cloud-config/default.yaml
grep -Fq 'auto: true' os/cloud-config/ci-install.yaml
grep -Fq '/var/lib/dead-rose' os/cloud-config/default.yaml

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
