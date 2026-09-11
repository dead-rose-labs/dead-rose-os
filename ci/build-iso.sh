#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
require_arch
stage_start build-iso
exec > >(tee "$ARTIFACTS/logs/archiso.log") 2>&1
[[ ! -e $FACTORY_WORK/archiso && ! -e $FACTORY_WORK/profile ]] || die 'Archiso work/profile must be fresh'
(cd "$ARTIFACTS" && sha256sum --check deadrose-repo.tar.sha256)
mkdir -p "$FACTORY_WORK/repository"
tar -xf "$ARTIFACTS/deadrose-repo.tar" -C "$FACTORY_WORK/repository"
(cd "$FACTORY_WORK/repository" && sha256sum --check SHA256SUMS)
[[ $(cat "$FACTORY_WORK/repository/commit") == "$GIT_COMMIT" ]] || die 'Package repository belongs to another commit'
python3 "$FACTORY_ROOT/ci/prepare-profile.py"
export DEAD_ROSE_ISO_VERSION="${DEAD_ROSE_VERSION}-g${GIT_SHORT_SHA}"
mkarchiso -v -r -w "$FACTORY_WORK/archiso" -o "$ARTIFACTS" "$FACTORY_WORK/profile"
test -s "$ARTIFACTS/$ISO_NAME"
(cd "$ARTIFACTS" && sha256sum "$ISO_NAME" > "$ISO_NAME.sha256")
pacman -Q archiso > "$ARTIFACTS/manifest/archiso.txt"
pacman -Q > "$ARTIFACTS/manifest/build-host-packages.txt"
stage_pass
