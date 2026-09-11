#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
require_arch
stage=${1:?Missing stage}
exec > >(tee "$ARTIFACTS/logs/environment-$stage.log") 2>&1
# This configures the disposable build host, never mutates repository sources.
install -m644 "$FACTORY_ROOT/archiso/pacman.conf" /etc/pacman.conf
mirror_repo="\$repo"
mirror_arch="\$arch"
printf 'Server = https://archive.archlinux.org/repos/%s/%s/os/%s\n' "$ARCH_SNAPSHOT" "$mirror_repo" "$mirror_arch" > /etc/pacman.d/mirrorlist
pacman -Syyuu --noconfirm
pacman -S --needed --noconfirm git python python-yaml python-jsonschema curl
case "$stage" in
    preflight) pacman -S --needed --noconfirm shellcheck desktop-file-utils archiso ;;
    build-packages) pacman -S --needed --noconfirm base-devel ;;
    build-iso|inspect-iso) pacman -S --needed --noconfirm archiso mtools squashfs-tools ;;
esac
exec "$FACTORY_ROOT/ci/$stage.sh"
