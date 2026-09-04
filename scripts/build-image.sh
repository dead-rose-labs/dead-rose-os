#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=versions.env
source "${repo_root}/versions.env"
version=$(tr -d '[:space:]' < "${repo_root}/VERSION")

if docker buildx version >/dev/null 2>&1; then
  buildx=(docker buildx)
elif command -v docker-buildx >/dev/null 2>&1; then
  buildx=(docker-buildx)
else
  printf 'docker buildx is required\n' >&2
  exit 1
fi

"${buildx[@]}" build \
  --platform linux/amd64 \
  --load \
  --build-arg "BASE_IMAGE=ubuntu:${UBUNTU_VERSION}" \
  --build-arg "UBUNTU_VERSION=${UBUNTU_VERSION}" \
  --build-arg "KAIROS_INIT_VERSION=${KAIROS_INIT_VERSION}" \
  --build-arg "RUST_VERSION=${RUST_VERSION}" \
  --build-arg "NODE_VERSION=${NODE_VERSION}" \
  --build-arg "PNPM_VERSION=${PNPM_VERSION}" \
  --build-arg "VERSION=${version}" \
  --tag "dead-rose-os:${version}" \
  --file "${repo_root}/os/Dockerfile" \
  "${repo_root}"
