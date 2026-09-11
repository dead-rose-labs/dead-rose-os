#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
stage_start boot-live
verify_iso_checksum
python3 "$FACTORY_ROOT/scripts/qemu-smoke.py" "$ARTIFACTS/$ISO_NAME" --output "$ARTIFACTS/logs" --timeout 300
stage_pass
