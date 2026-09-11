#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
stage_start artifact
for required in preflight calamares-schema build-packages build-iso inspect-iso boot-live; do
    [[ $(cat "$ARTIFACTS/status/$required") == passed ]] || die "Missing successful stage: $required"
done
"$FACTORY_ROOT/ci/create-manifest.sh"
python3 - <<'PY'
import json, os
from pathlib import Path
data = json.loads((Path(os.environ['ARTIFACTS']) / 'logs/qemu-result.json').read_text())
assert data['passed'] and all(data['markers'].values()), 'All three live readiness markers required'
PY
# create-manifest has its own process and trap; this process still records artifact.
stage_pass
"$FACTORY_ROOT/ci/summary.sh"
