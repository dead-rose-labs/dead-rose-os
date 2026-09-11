#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
stage_start create-manifest
verify_iso_checksum
python3 "$FACTORY_ROOT/ci/create-manifest.py"
verify_iso_checksum
stage_pass
