#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
stage_start calamares-schema
exec > >(tee "$ARTIFACTS/logs/calamares-schema.log") 2>&1
"$FACTORY_ROOT/ci/fetch-calamares.sh"
python3 "$FACTORY_ROOT/ci/validate-calamares.py" "$FACTORY_WORK/upstream/calamares-$CALAMARES_COMMIT"
stage_pass
