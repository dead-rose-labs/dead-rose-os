#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
stage=${1:?Usage: ci/run-arch.sh STAGE}
case "$stage" in preflight|validate-calamares|build-packages|build-iso|inspect-iso|create-manifest) ;; *) die "Unsupported stage: $stage" ;; esac
if [[ $stage == build-iso ]]; then
    privilege_flag=--privileged
else
    privilege_flag=
fi
docker run --rm --platform linux/amd64 ${privilege_flag:+"$privilege_flag"} \
    -v "$FACTORY_ROOT:/src:ro" -v "$ARTIFACTS:/artifacts" -w /src \
    -e FACTORY_ROOT=/src -e ARTIFACTS=/artifacts -e FACTORY_WORK=/work \
    -e GIT_COMMIT -e SOURCE_DATE_EPOCH \
    -e GITHUB_REF -e GITHUB_REF_TYPE -e GITHUB_REF_NAME -e GITHUB_RUN_ID \
    "$ARCH_CONTAINER_REPOSITORY@$ARCH_CONTAINER_DIGEST" \
    /src/ci/arch-entry.sh "$stage"
