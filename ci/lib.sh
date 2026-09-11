#!/usr/bin/env bash
# Shared paths and error reporting; no build implementation in workflow YAML.
set -Eeuo pipefail
FACTORY_ROOT=${FACTORY_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}
export FACTORY_ROOT
# shellcheck source=versions.env
source "$FACTORY_ROOT/versions.env"
export DEAD_ROSE_VERSION ARCH_SNAPSHOT CALAMARES_VERSION CALAMARES_COMMIT CALAMARES_SHA256
export ARCH_CONTAINER_REPOSITORY ARCH_CONTAINER_DIGEST
ARTIFACTS=${ARTIFACTS:-$FACTORY_ROOT/artifacts}
FACTORY_WORK=${FACTORY_WORK:-/var/tmp/deadrose-factory}
export ARTIFACTS FACTORY_WORK
mkdir -p "$ARTIFACTS/logs" "$ARTIFACTS/manifest" "$ARTIFACTS/status"
GIT_COMMIT=${GIT_COMMIT:-$(git -C "$FACTORY_ROOT" rev-parse HEAD)}
GIT_SHORT_SHA=${GIT_COMMIT:0:7}
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git -C "$FACTORY_ROOT" show -s --format=%ct HEAD)}
ISO_NAME="dead-rose-os-${DEAD_ROSE_VERSION}-g${GIT_SHORT_SHA}-x86_64.iso"
export GIT_COMMIT GIT_SHORT_SHA SOURCE_DATE_EPOCH ISO_NAME
export DEAD_ROSE_VERSIONS_FILE="$FACTORY_ROOT/versions.env"

die() { echo "ERROR: $*" >&2; exit 1; }
stage_start() {
    STAGE=$1
    export STAGE
    printf 'running\n' > "$ARTIFACTS/status/$STAGE"
    trap 'result=$?; printf "failed (%s), line %s\n" "$result" "$LINENO" > "$ARTIFACTS/status/$STAGE"; echo "ERROR: $STAGE failed at line $LINENO (exit $result)" >&2; exit "$result"' ERR
}
stage_pass() { printf 'passed\n' > "$ARTIFACTS/status/$STAGE"; }
require_arch() {
    [[ $(uname -s) == Linux && $(uname -m) == x86_64 && -f /etc/arch-release ]] || die 'This stage requires Arch Linux x86_64. Use ci/run-arch.sh.'
    (( EUID == 0 )) || die 'Run in the dedicated root build container; makepkg itself runs unprivileged.'
}
verify_iso_checksum() { (cd "$ARTIFACTS" && sha256sum --check "$ISO_NAME.sha256"); }
