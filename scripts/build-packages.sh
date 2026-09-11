#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
destination=$1
mkdir -p "$destination/repo" "$destination/calamares" "$destination/dead-rose-config"
# makepkg must run as an unprivileged build user. This account lives in the
# builder, never in the resulting image. Dependencies are installed explicitly.
if ! id deadrose-builder >/dev/null 2>&1; then
    useradd --system --create-home deadrose-builder
fi
pacman -S --needed --noconfirm base-devel cmake ninja extra-cmake-modules boost boost-libs icu parted qt6-base \
    qt6-tools qt6-declarative qt6-svg qt6-5compat polkit-qt6 yaml-cpp kpmcore \
    kconfig kcoreaddons kcrash kiconthemes kio libpwquality python python-yaml python-jsonschema \
    librsvg noto-fonts rsync squashfs-tools gptfdisk
cp "$repo/packaging/calamares/PKGBUILD" "$destination/calamares/"
cp "$repo/packaging/dead-rose-config/PKGBUILD" "$destination/dead-rose-config/"
tar -cf "$destination/calamares/deadrose-config.tar" -C "$repo" calamares
tar -cf "$destination/dead-rose-config/deadrose-assets.tar" -C "$repo" branding config apps LICENSE
chown -R deadrose-builder:deadrose-builder "$destination"
for package in calamares dead-rose-config; do
    # --nodeps only for the artwork package: runtime dependencies are resolved
    # by pacstrap; its two build dependencies were installed above.
    options=()
    [[ $package != dead-rose-config ]] || options+=(--nodeps)
    runuser -u deadrose-builder -- bash -c 'cd -- "$1"; shift; makepkg --cleanbuild --noconfirm "$@"' \
        bash "$destination/$package" "${options[@]}"
    cp "$destination/$package/"*.pkg.tar.zst "$destination/repo/"
done
repo-add "$destination/repo/deadrose-local.db.tar.gz" "$destination/repo/"*.pkg.tar.zst
