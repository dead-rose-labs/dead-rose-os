#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
{
    printf 'iso_name=%s\n' "$ISO_NAME"
    printf 'artifact_name=dead-rose-os-%s-g%s\n' "$DEAD_ROSE_VERSION" "$GIT_SHORT_SHA"
    printf 'version=%s\n' "$DEAD_ROSE_VERSION"
} | tee -a "${GITHUB_OUTPUT:-/dev/stdout}"
