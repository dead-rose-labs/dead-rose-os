#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(tr -d '[:space:]' < "${repo_root}/VERSION")
image="dead-rose-os:${version}"

docker run --rm \
  --entrypoint /bin/bash \
  -v "${repo_root}/tests/integration/image-sanity.sh:/tmp/image-sanity.sh:ro" \
  "${image}" /tmp/image-sanity.sh
