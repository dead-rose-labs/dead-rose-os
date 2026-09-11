#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
python3 "$FACTORY_ROOT/ci/summary.py" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
