#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
mkdir -p "$FACTORY_WORK/upstream"
archive="$FACTORY_WORK/upstream/calamares-$CALAMARES_COMMIT.tar.gz"
curl --fail --location --show-error --connect-timeout 30 --max-time 180 \
    "https://codeload.github.com/calamares/calamares/tar.gz/$CALAMARES_COMMIT" -o "$archive"
printf '%s  %s\n' "$CALAMARES_SHA256" "$archive" | sha256sum --check
tar -xzf "$archive" -C "$FACTORY_WORK/upstream"
