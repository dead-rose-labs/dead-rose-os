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
