#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
command -v rg >/dev/null || { echo "MISSING rg: install ripgrep (https://github.com/BurntSushi/ripgrep)" >&2; exit 1; }
required=(VERSION DESIGN.md os/mkosi.conf os/mkosi.repart/10-esp.conf os/mkosi.repart/20-root-a.conf os/mkosi.repart/30-root-b.conf os/mkosi.repart/40-state.conf os/installer/grub-bootstrap.cfg os/installer/grub.cfg os/installer/mkosi.initrd.conf os/installer/mkosi.initrd.extra/etc/fstab os/installer/mkosi.initrd.extra/usr/lib/dead-rose-initrd/mount-live-root os/installer/mkosi.initrd.extra/usr/lib/systemd/system/dead-rose-live-root.service os/installer/mkosi.initrd.extra/usr/lib/systemd/system/initrd-switch-root.service.d/dead-rose-console.conf os/installer/mkosi.initrd.extra/usr/lib/systemd/system/initrd-switch-root.target.d/dead-rose-live-root.conf os/systemd/dead-rose-core.service os/systemd/dead-rose-graphical.service os/systemd/dead-rose-installer.service apps/shell/src-tauri/tauri.conf.json apps/installer/src-tauri/tauri.conf.json tests/integration/installer-iso.sh tests/integration/live-root.sh tests/boot/installer-iso-smoke.sh)
for path in "${required[@]}"; do [[ -f "$project_dir/$path" ]] || { echo "Missing $path" >&2; exit 1; }; done
if rg -n "localStorage|sessionStorage|run_command|Command::new\(.*sh" "$project_dir/apps" "$project_dir/crates"; then echo "Forbidden runtime pattern found" >&2; exit 1; fi
if rg -n '^Output=.*[/\\]' "$project_dir/os" --glob mkosi.conf; then echo "mkosi Output must be a filename without path components" >&2; exit 1; fi

# Each mkosi package-list entry must be its own line/value. A single-line
# whitespace-separated "Packages=a b c" is passed to apt as ONE quoted package
# name and fails with "Unable to locate package". Apply to every package-list
# setting so a regression in any of them is caught.
if awk '
  {
    if ($0 ~ /^[A-Za-z]+=/) {
      setting = $0
      sub(/=.*/, "", setting)
      in_pkglist = (setting ~ /^(Packages|BuildPackages|VolatilePackages|InitrdPackages|ToolsTreePackages|PackageDirectories)$/)
      if (in_pkglist) {
        value = $0
        sub(/^[^=]*=/, "", value)
        if (value ~ / /) { print FILENAME ":" FNR ": " $0; bad = 1 }
      }
    } else if (in_pkglist && $0 ~ /^[ \t]/) {
      value = $0
      sub(/^[ \t]+/, "", value)
      if (value ~ / /) { print FILENAME ":" FNR ": " $0; bad = 1 }
    } else {
      in_pkglist = 0
    }
  }
  END { exit bad ? 1 : 0 }
' "$project_dir/os/mkosi.conf" "$project_dir/os/installer/mkosi.conf"
then
  :
else
  echo "mkosi package-list settings must list one package per line, not a whitespace-separated single-line list" >&2
  exit 1
fi

# The installer live root must keep the ownership the OS image assigns. A
# recursive chown to the build user or an unprivileged mksquashfs both flatten
# ownership to the runner uid (1001) and silently pack /etc/shadow empty, so
# the staging logic must be privileged and validated after packing.
iso_build="$project_dir/scripts/build-iso.sh"
if rg -n 'chown -R' "$iso_build" "$project_dir/scripts/build-os.sh"; then
  echo "OS/installer roots must not be recursively chowned to the build user" >&2
  exit 1
fi
if rg -q 'zstd .*\|.*tee' "$iso_build" || ! rg -q 'zstd .*--sparse' "$iso_build"; then
  echo "the embedded raw image must be decompressed sparsely instead of materialized through tee" >&2
  exit 1
fi
if ! rg -q 'chown 0:0 .*embedded_raw' "$iso_build"; then
  echo "the embedded raw image must be restored to root ownership after zstd copies input metadata" >&2
  exit 1
fi
if ! rg -q 'sudo mksquashfs' "$iso_build"; then
  echo "mksquashfs must run with privileges so privileged files and ownership are preserved" >&2
  exit 1
fi
if ! rg -q 'squashfs\.sh' "$iso_build"; then
  echo "build-iso.sh must validate the squashfs after packing" >&2
  exit 1
fi
if ! rg -q '^SplitArtifacts=kernel,initrd$' "$project_dir/os/installer/mkosi.conf"; then
  echo "the installer image must explicitly export mkosi kernel and initrd artifacts" >&2
  exit 1
fi
for artifact in installer_kernel installer_initrd; do
  if ! rg -q "sudo install .*\\\$$artifact" "$iso_build"; then
    echo "the mkosi $artifact split artifact must be staged with sudo install" >&2
    exit 1
  fi
done
if rg -q 'resolve_single_boot_artifact' "$iso_build"; then
  echo "build-iso.sh must use mkosi's split initrd instead of searching the image root" >&2
  exit 1
fi
if rg -q '^[[:space:]]*(sudo[[:space:]]+)?lsinitramfs([[:space:]]|$)' "$iso_build"; then
  echo "build-iso.sh must not inspect mkosi's composite initrd with lsinitramfs" >&2
  exit 1
fi

grub_config="$project_dir/os/installer/grub.cfg"
grub_bootstrap="$project_dir/os/installer/grub-bootstrap.cfg"
live_root="$project_dir/os/installer/mkosi.initrd.extra/usr/lib/dead-rose-initrd/mount-live-root"
live_root_unit="$project_dir/os/installer/mkosi.initrd.extra/usr/lib/systemd/system/dead-rose-live-root.service"
initrd_fstab="$project_dir/os/installer/mkosi.initrd.extra/etc/fstab"
switch_root_target_dropin="$project_dir/os/installer/mkosi.initrd.extra/usr/lib/systemd/system/initrd-switch-root.target.d/dead-rose-live-root.conf"
installer_unit="$project_dir/os/systemd/dead-rose-installer.service"

[[ -x "$live_root" ]] || { echo "Dead Rose initrd live-root helper must be executable" >&2; exit 1; }
[[ -x "$project_dir/tests/integration/installer-iso.sh" ]] || { echo "installer ISO check must be executable" >&2; exit 1; }
[[ -x "$project_dir/tests/integration/live-root.sh" ]] || { echo "live-root integration check must be executable" >&2; exit 1; }
[[ -x "$project_dir/tests/boot/installer-iso-smoke.sh" ]] || { echo "installer ISO smoke test must be executable" >&2; exit 1; }
rg -q 'if=pflash.*firmware_code' "$project_dir/tests/boot/installer-iso-smoke.sh" || { echo "installer ISO smoke test must load OVMF CODE through pflash" >&2; exit 1; }
rg -q 'if=pflash.*firmware_vars' "$project_dir/tests/boot/installer-iso-smoke.sh" || { echo "installer ISO smoke test must use a writable OVMF VARS image" >&2; exit 1; }
if rg -q -- '-bios' "$project_dir/tests/boot/installer-iso-smoke.sh"; then echo "installer ISO smoke test must not load 4M OVMF through legacy -bios" >&2; exit 1; fi
rg -q 'systemctl status initrd-switch-root.service' "$project_dir/tests/boot/installer-iso-smoke.sh" || { echo "installer ISO smoke test must collect switch-root diagnostics in emergency mode" >&2; exit 1; }
rg -q 'live root mount validation completed successfully' "$project_dir/tests/boot/installer-iso-smoke.sh" || { echo "installer ISO smoke test must observe validated systemd-owned live-root mounts" >&2; exit 1; }
rg -q 'search --no-floppy --label DEAD_ROSE_INSTALLER --set=root' "$grub_config" || { echo "GRUB must locate installer media by filesystem label" >&2; exit 1; }
rg -q 'menuentry "Dead Rose OS Installer"' "$grub_config" || { echo "GRUB must provide the installer menu entry" >&2; exit 1; }
rg -q 'configfile .*boot/grub/grub.cfg' "$grub_bootstrap" || { echo "embedded GRUB bootstrap must load the external menu" >&2; exit 1; }
if rg -q 'set[[:space:]]+prefix=.*\$root' "$grub_bootstrap"; then
  echo "standalone GRUB must keep prefix on its memdisk so platform modules remain available" >&2
  exit 1
fi
rg -q 'grub-bootstrap.cfg' "$iso_build" || { echo "standalone GRUB must embed the bootstrap config" >&2; exit 1; }
if rg -q '\(cd0\)|boot=live' "$grub_config"; then
  echo "GRUB must not depend on cd0 numbering or the unused Debian live-boot path" >&2
  exit 1
fi
rg -q '^LABEL=DEAD_ROSE_INSTALLER[[:space:]]+/run/dead-rose-iso' "$initrd_fstab" || { echo "initrd must locate installer media by filesystem label" >&2; exit 1; }
[[ "$(rg -o 'x-initrd\.mount' "$initrd_fstab" | wc -l | tr -d ' ')" == 2 ]] || { echo "both installer mounts must be owned by the initrd mount transaction" >&2; exit 1; }
rg -q 'x-systemd\.device-timeout=60s' "$initrd_fstab" || { echo "installer media mount must tolerate delayed device discovery" >&2; exit 1; }
rg -q 'x-systemd\.requires-mounts-for=/run/dead-rose-iso' "$initrd_fstab" || { echo "live root mount must depend on its ISO backing mount" >&2; exit 1; }
if rg -q '/dev/sr0' "$initrd_fstab" "$live_root"; then echo "initrd must not hard-code optical device names" >&2; exit 1; fi
if rg -q '^[[:space:]]*mount[[:space:]]' "$live_root"; then echo "live-root helper must leave mount ownership to systemd" >&2; exit 1; fi
rg -q 'mounted root does not provide /sbin/init' "$live_root" || { echo "initrd must validate the target OS tree before switch-root" >&2; exit 1; }
rg -q 'installer root is missing switch-root mount point' "$iso_build" || { echo "ISO build must prepare systemd switch-root mount points" >&2; exit 1; }
rg -q 'Before=initrd-root-fs.target' "$live_root_unit" || { echo "live-root mount must complete before initrd-root-fs.target" >&2; exit 1; }
rg -q 'RequiresMountsFor=/run/dead-rose-iso /sysroot' "$live_root_unit" || { echo "live-root validation must require both initrd mounts" >&2; exit 1; }
rg -q 'RequiresMountsFor=/run/dead-rose-iso /sysroot' "$switch_root_target_dropin" || { echo "switch-root transaction must retain the live root and its ISO backing mount" >&2; exit 1; }
rg -q 'RuntimeDirectory=dead-rose-cage' "$installer_unit" || { echo "installer Cage service must create its runtime directory" >&2; exit 1; }
rg -q 'Environment=XDG_RUNTIME_DIR=/run/dead-rose-cage' "$installer_unit" || { echo "installer Cage service must set XDG_RUNTIME_DIR" >&2; exit 1; }
rg -q 'Requires=systemd-logind.service' "$installer_unit" || { echo "installer Cage service must expose logind failures as a hard dependency" >&2; exit 1; }
rg -q 'PAMName=login' "$installer_unit" || { echo "installer Cage service must register a logind session for its TTY seat" >&2; exit 1; }
rg -q 'installer-iso\.sh' "$iso_build" || { echo "build-iso.sh must validate the completed ISO" >&2; exit 1; }
rg -Fq "Volume [Ii]d" "$project_dir/tests/integration/installer-iso.sh" || { echo "installer ISO check must accept xorriso volume-id capitalization variants" >&2; exit 1; }
rg -q 'installer-iso-smoke\.sh' "$project_dir/.github/workflows/build-os.yml" || { echo "CI must smoke-test the installer ISO boot" >&2; exit 1; }
rg -q 'installer-iso-smoke\.sh' "$project_dir/.github/workflows/image.yml" || { echo "privileged image CI must smoke-test the installer ISO boot" >&2; exit 1; }

squashfs_test="$project_dir/tests/integration/squashfs.sh"
[[ -x "$squashfs_test" ]] || { echo "squashfs regression test is missing or not executable: $squashfs_test" >&2; exit 1; }
rg -q 'etc/shadow' "$squashfs_test" || { echo "squashfs regression test must assert presence of /etc/shadow" >&2; exit 1; }
rg -q 'etc/gshadow' "$squashfs_test" || { echo "squashfs regression test must assert presence of /etc/gshadow" >&2; exit 1; }

echo "Repository invariants pass."
