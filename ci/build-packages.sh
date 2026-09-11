#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
require_arch
stage_start build-packages
exec > >(tee "$ARTIFACTS/logs/packages.log") 2>&1
destination="$FACTORY_WORK/packages"
[[ ! -e $destination ]] || die 'Package work directory must be fresh'
mkdir -p "$destination" "$ARTIFACTS/logs/packages"
pacman -S --needed --noconfirm base-devel cmake ninja extra-cmake-modules boost boost-libs icu parted qt6-base \
    qt6-tools qt6-declarative qt6-svg qt6-5compat polkit-qt6 yaml-cpp kpmcore \
    kconfig kcoreaddons kcrash kiconthemes kio libpwquality python python-yaml python-jsonschema \
    librsvg noto-fonts rsync squashfs-tools gptfdisk plasma-desktop sddm plymouth kdialog chromium
useradd --system --create-home deadrose-builder
for package in calamares dead-rose-calamares-config dead-rose-config; do
    mkdir -p "$destination/$package"
    cp "$FACTORY_ROOT/packaging/$package/PKGBUILD" "$destination/$package/"
done
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner \
    -cf "$destination/dead-rose-calamares-config/deadrose-installer.tar" -C "$FACTORY_ROOT" calamares branding/calamares
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner \
    --exclude=branding/calamares -cf "$destination/dead-rose-config/deadrose-assets.tar" \
    -C "$FACTORY_ROOT" branding config apps LICENSE
INSTALLER_ASSETS_SHA256=$(sha256sum "$destination/dead-rose-calamares-config/deadrose-installer.tar" | cut -d ' ' -f1)
DESKTOP_ASSETS_SHA256=$(sha256sum "$destination/dead-rose-config/deadrose-assets.tar" | cut -d ' ' -f1)
export INSTALLER_ASSETS_SHA256 DESKTOP_ASSETS_SHA256
chown -R deadrose-builder:deadrose-builder "$destination"
repository="$destination/repository"
mkdir -p "$repository"
for package in calamares dead-rose-calamares-config dead-rose-config; do
    runuser -u deadrose-builder -- env \
        DEAD_ROSE_VERSIONS_FILE="$DEAD_ROSE_VERSIONS_FILE" \
        INSTALLER_ASSETS_SHA256="$INSTALLER_ASSETS_SHA256" \
        DESKTOP_ASSETS_SHA256="$DESKTOP_ASSETS_SHA256" \
        bash "$FACTORY_ROOT/ci/makepkg-in-dir.sh" "$destination/$package" 2>&1 | tee "$ARTIFACTS/logs/packages/$package.log"
    files=("$destination/$package/"*.pkg.tar.zst)
    [[ ${#files[@]} == 1 && -s ${files[0]} ]] || die "Expected exactly one package for $package"
    pacman -Qp "${files[0]}" | tee -a "$ARTIFACTS/manifest/custom-packages.txt"
    cp "${files[0]}" "$repository/"
    # Allows makepkg to check the config package's upstream runtime dependency.
    [[ $package != calamares ]] || pacman -U --noconfirm "${files[0]}"
done
repo-add "$repository/deadrose.db.tar.gz" "$repository/"*.pkg.tar.zst
bsdtar -tf "$repository/deadrose.db.tar.gz" > "$ARTIFACTS/logs/repository-entries.txt"
cp "$ARTIFACTS/manifest/custom-packages.txt" "$repository/packages.txt"
printf '%s\n' "$GIT_COMMIT" > "$repository/commit"
(cd "$repository" && sha256sum ./*.pkg.tar.zst deadrose.db.tar.gz deadrose.files.tar.gz packages.txt commit > SHA256SUMS)
(cd "$repository" && sha256sum --check SHA256SUMS)
tar -cf "$ARTIFACTS/deadrose-repo.tar" -C "$repository" .
(cd "$ARTIFACTS" && sha256sum deadrose-repo.tar > deadrose-repo.tar.sha256)
stage_pass
