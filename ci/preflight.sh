#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
stage_start preflight
log_file="$ARTIFACTS/logs/preflight.log"
run_preflight() {
    cd "$FACTORY_ROOT"
    while IFS= read -r -d '' file; do
        printf 'shellcheck %s\n' "$file"
        bash -n "$file"
        shellcheck --external-sources --source-path=. "$file"
    done < <(find ci scripts -type f -name '*.sh' -print0)
    printf 'shellcheck dr\n'
    bash -n dr
    shellcheck --external-sources --source-path=. dr
    for file in packaging/*/PKGBUILD archiso/profiledef.sh; do bash -n "$file"; done
    python3 scripts/validate-profile.py
    python3 ci/preflight.py
    desktop_roots=(apps)
    [[ ! -d archiso/airootfs/usr/share/applications ]] || desktop_roots+=(archiso/airootfs/usr/share/applications)
    while IFS= read -r -d '' file; do desktop-file-validate "$file"; done < <(find "${desktop_roots[@]}" -name '*.desktop' -print0)
    # Real upstream unit parser; executable existence belongs to ISO inspection.
    systemd-analyze verify --man=no ci/live/*.service
}
run_preflight 2>&1 | tee "$log_file"
status=${PIPESTATUS[0]}
(( status == 0 ))
stage_pass
