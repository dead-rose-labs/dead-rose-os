#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
[[ ${GITHUB_REF_TYPE:-} == tag && ${GITHUB_REF_NAME:-} == "v$DEAD_ROSE_VERSION" ]] || die 'Release requires a matching version tag'
[[ $(cat "$ARTIFACTS/status/artifact") == passed ]] || die 'Factory acceptance has not passed'
verify_iso_checksum
python3 - <<'PY'
import json, os
from pathlib import Path
data = json.loads((Path(os.environ['ARTIFACTS']) / 'manifest/build.json').read_text())
assert data['git_commit'] == os.environ['GIT_COMMIT'], 'Release commit mismatch'
assert data['dead_rose_version'] == os.environ['DEAD_ROSE_VERSION'], 'Release version mismatch'
PY
notes=$(mktemp)
trap 'rm -f "$notes"' EXIT
python3 "$FACTORY_ROOT/ci/summary.py" > "$notes"
gh release create "$GITHUB_REF_NAME" --repo "$GITHUB_REPOSITORY" --verify-tag --draft \
    --title "Dead Rose OS $DEAD_ROSE_VERSION" --notes-file "$notes" \
    "$ARTIFACTS/$ISO_NAME" "$ARTIFACTS/$ISO_NAME.sha256" \
    "$ARTIFACTS/manifest/build.json" "$ARTIFACTS/manifest/packages.txt"
gh release edit "$GITHUB_REF_NAME" --repo "$GITHUB_REPOSITORY" --draft=false
