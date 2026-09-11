#!/usr/bin/env bash
set -Eeuo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
case "${1:---iso}" in
    --source) exec "$repo/ci/preflight.sh" ;;
    --iso) exec "$repo/ci/inspect-iso.sh" ;;
    *) echo "Usage: $0 [--source | --iso] (ISO is selected from versions.env and HEAD)" >&2; exit 2 ;;
esac
