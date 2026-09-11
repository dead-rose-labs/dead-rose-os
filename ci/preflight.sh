#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
stage_start preflight
exec > >(tee "$ARTIFACTS/logs/preflight.log") 2>&1
cd "$FACTORY_ROOT"
while IFS= read -r -d '' file; do
    printf 'shellcheck %s\n' "$file"
    bash -n "$file"
    shellcheck --external-sources --source-path=SCRIPTDIR "$file"
done < <(find ci scripts -type f -name '*.sh' -print0)
for file in packaging/*/PKGBUILD archiso/profiledef.sh; do bash -n "$file"; done
python3 scripts/validate-profile.py
python3 ci/preflight.py
while IFS= read -r -d '' file; do desktop-file-validate "$file"; done < <(find apps archiso/airootfs/usr/share/applications -name '*.desktop' -print0)
# Real upstream unit parser; executable existence belongs to ISO inspection.
systemd-analyze verify --man=no ci/live/*.service
stage_pass
