#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
command -v rg >/dev/null || { echo "MISSING rg" >&2; exit 1; }

required=(
  VERSION DESIGN.md os/mkosi.conf os/installer/mkosi.conf
  os/greetd/installed.toml os/greetd/installer.toml
  os/pam/greetd
  os/systemd/greetd-installed.conf os/systemd/greetd-installer.conf
  os/systemd/dead-rose-core.service os/systemd/dead-rose-installer-backend.service
  os/systemd/dead-rose-state-init.service
  os/grub/99-dead-rose.cfg os/installer/grub.cfg
  crates/session/src/main.rs crates/installer-agent/src/main.rs
  docs/architecture/rebuild-audit.md docs/architecture/os-runtime.md docs/build.md docs/debug.md
  tests/boot/smoke.sh tests/boot/installer-iso-smoke.sh
)
for path in "${required[@]}"; do [[ -f "$project_dir/$path" ]] || { echo "Missing $path" >&2; exit 1; }; done

for obsolete in os/systemd/dead-rose-graphical.service os/systemd/dead-rose-installer.service os/systemd/dead-rose-state.mount os/cage/environment os/mkosi.repart patches/curtin/dd-bmap.patch; do
  [[ ! -e "$project_dir/$obsolete" ]] || { echo "Obsolete runtime file remains: $obsolete" >&2; exit 1; }
done

if rg -n 'XDG_RUNTIME_DIR|RuntimeDirectory=dead-rose-cage|PAMName=login|ExecStart=.*/cage' "$project_dir/os"; then
  echo "Graphical session lifecycle must belong to greetd/PAM/logind" >&2
  exit 1
fi
if rg -n 'localStorage|sessionStorage|run_command|Command::new\(.*sh' "$project_dir/apps" "$project_dir/crates"; then
  echo "Forbidden runtime pattern found" >&2
  exit 1
fi

rg -q '^Format=directory$' "$project_dir/os/mkosi.conf"
rg -q '^[[:space:]]+greetd$' "$project_dir/os/mkosi.conf"
rg -q '^[[:space:]]+greetd$' "$project_dir/os/installer/mkosi.conf"
rg -q '^[[:space:]]+login$' "$project_dir/os/mkosi.conf"
rg -q '^[[:space:]]+login$' "$project_dir/os/installer/mkosi.conf"
rg -q '^[[:space:]]+systemd-resolved$' "$project_dir/os/installer/mkosi.conf"
rg -q '^[[:space:]]+apt$' "$project_dir/os/installer/mkosi.conf"
rg -q '^[[:space:]]+iproute2$' "$project_dir/os/installer/mkosi.conf"
rg -q '^[[:space:]]+lsb-release$' "$project_dir/os/installer/mkosi.conf"
rg -q '^[[:space:]]+sudo$' "$project_dir/os/installer/mkosi.conf"
rg -q '^[[:space:]]+lshw$' "$project_dir/os/installer/mkosi.conf"
rg -q '^[[:space:]]+apt$' "$project_dir/os/mkosi.conf"
rg -q '^[[:space:]]+lsb-release$' "$project_dir/os/mkosi.conf"
rg -q '^[[:space:]]+grub-efi-amd64-signed$' "$project_dir/os/mkosi.conf"
rg -q '^[[:space:]]+shim-signed$' "$project_dir/os/mkosi.conf"
rg -q '^[[:space:]]+e2fsprogs$' "$project_dir/os/mkosi.conf"
if rg -q '^[[:space:]]+curtin$' "$project_dir/os/installer/mkosi.conf"; then
  echo "Ubuntu 26.04 does not ship a curtin binary package; use the pinned source runtime" >&2
  exit 1
fi
rg -q '^curtin_commit="[0-9a-f]{40}"$' "$project_dir/scripts/stage-curtin.sh"
rg -q '^curtin_sha256="[0-9a-f]{64}"$' "$project_dir/scripts/stage-curtin.sh"
rg -q 'extract_root_tgz_url' "$project_dir/scripts/stage-curtin.sh"
if rg -n 'ROOT-A|ROOT-B|PARTNAME=STATE|dd-bmap|bmaptool|systemd-repart|raw\.zst|raw\.bmap' \
  "$project_dir/os" "$project_dir/scripts" "$project_dir/crates"; then
  echo "Obsolete A/B, STATE or raw-image installation architecture remains" >&2
  exit 1
fi
if rg -q 'gnome-shell|gdm3|ubuntu-desktop|plasma-desktop|xfce4' "$project_dir/os" --glob 'mkosi.conf'; then
  echo "A conventional desktop package is forbidden" >&2
  exit 1
fi

rg -q '^user = "deadrose-ui"$' "$project_dir/os/greetd/installed.toml"
rg -q 'dead-rose-session /usr/lib/dead-rose/dead-rose-shell' "$project_dir/os/greetd/installed.toml"
rg -q '^user = "deadrose-installer"$' "$project_dir/os/greetd/installer.toml"
rg -q 'dead-rose-session /usr/lib/dead-rose/dead-rose-installer' "$project_dir/os/greetd/installer.toml"
rg -q '^@include login$' "$project_dir/os/pam/greetd"
rg -q 'os/pam/greetd.*etc/pam\.d/greetd' "$project_dir/scripts/build-os.sh"
rg -q 'os/pam/greetd.*etc/pam\.d/greetd' "$project_dir/scripts/build-iso.sh"
if rg -q 'agreety|/bin/login' "$project_dir/os/greetd"; then
  echo "The kiosk VT must not fall through to an interactive login prompt" >&2
  exit 1
fi
if rg -q '"fullscreen"[[:space:]]*:[[:space:]]*true' "$project_dir/apps/installer/src-tauri/tauri.conf.json" "$project_dir/apps/shell/src-tauri/tauri.conf.json"; then
  echo "Cage owns kiosk fullscreen; clients must not request fullscreen before their xdg surface is mapped" >&2
  exit 1
fi
rg -q '^u deadrose-ui .*nologin$' "$project_dir/os/sysusers/dead-rose.conf"
rg -q '^u deadrose-installer .*nologin$' "$project_dir/os/sysusers/dead-rose.conf"
rg -q '^u deadrose-ui .* /var/lib/dead-rose-ui /usr/sbin/nologin$' "$project_dir/os/sysusers/dead-rose.conf"
rg -q '^u deadrose-installer .* /var/lib/dead-rose-installer /usr/sbin/nologin$' "$project_dir/os/sysusers/dead-rose.conf"
rg -q '^d /var/lib/dead-rose 0750 deadrose-core deadrose-core -$' "$project_dir/os/tmpfiles/dead-rose.conf"
rg -q '^d /var/lib/dead-rose-ui 0750 deadrose-ui deadrose-ui -$' "$project_dir/os/tmpfiles/dead-rose.conf"
rg -q '^d /var/lib/dead-rose-installer 0750 deadrose-installer deadrose-installer -$' "$project_dir/os/tmpfiles/dead-rose.conf"
rg -q -- '--prefix=/var/lib/dead-rose-installer' "$project_dir/scripts/build-iso.sh"
if rg -q '^m deadrose-(ui|installer) (video|render|input)$' "$project_dir/os/sysusers/dead-rose.conf"; then
  echo "greetd/logind sessions must not require permanent device-group membership" >&2
  exit 1
fi
rg -q '^User=root$' "$project_dir/os/systemd/dead-rose-installer-backend.service"
rg -q '^Group=deadrose-installer-ipc$' "$project_dir/os/systemd/dead-rose-installer-backend.service"
rg -q '^RestrictSUIDSGID=no$' "$project_dir/os/systemd/dead-rose-installer-backend.service"
rg -q '^Wants=.*systemd-resolved\.service$' "$project_dir/os/systemd/dead-rose-installer-backend.service"
rg -q '^Environment=DEAD_ROSE_PAYLOAD=/usr/lib/dead-rose-installer/dead-rose-os.rootfs.tar.gz$' "$project_dir/os/systemd/dead-rose-installer-backend.service"
rg -q '^Environment=DEAD_ROSE_TARGET_MOUNT=/run/dead-rose-installer/target$' "$project_dir/os/systemd/dead-rose-installer-backend.service"

rg -q 'InstallerRequest::Install' "$project_dir/apps/installer/src-tauri/src/main.rs"
rg -q 'UnixStream::connect' "$project_dir/apps/installer/src-tauri/src/main.rs"
if rg -q 'dead-rose-installer-core|nix.workspace' "$project_dir/apps/installer/src-tauri/Cargo.toml"; then
  echo "Installer Tauri process must not contain privileged disk implementation" >&2
  exit 1
fi
rg -q 'Command::new\("/usr/bin/curtin"\)' "$project_dir/crates/installer-agent/src/main.rs"
rg -q 'Command::new\("/usr/sbin/partprobe"\)' "$project_dir/crates/installer-agent/src/main.rs"
rg -q 'Command::new\("/usr/bin/udevadm"\)' "$project_dir/crates/installer-agent/src/main.rs"
rg -q '/dev/disk/by-id' "$project_dir/crates/installer-agent/src/main.rs"
rg -q 'wait_for_partition\(&disk\.device, "ROOT"\)' "$project_dir/crates/installer-agent/src/main.rs"
rg -q 'partition_name: EFI' "$project_dir/crates/installer-agent/src/main.rs"
rg -q 'partition_name: ROOT' "$project_dir/crates/installer-agent/src/main.rs"
rg -q 'type: tgz' "$project_dir/crates/installer-agent/src/main.rs"
rg -q 'installation_in_progress' "$project_dir/crates/installer-agent/src/main.rs"
rg -q 'repair_state_ownership' "$project_dir/crates/session/src/bin/dead-rose-state-init.rs"
rg -q 'tracing_journald::layer' "$project_dir/crates/session/src/main.rs"
rg -q 'relay_output\("cage stderr"' "$project_dir/crates/session/src/main.rs"
rg -q 'journalctl .*_UID=' "$project_dir/tests/boot/assets/smoke-diagnostics"

rg -q '^ID=deadrose$' "$project_dir/os/mkosi.extra/etc/os-release"
rg -q '^ID_LIKE="ubuntu debian"$' "$project_dir/os/mkosi.extra/etc/os-release"
rg -q '^UBUNTU_CODENAME=resolute$' "$project_dir/os/mkosi.extra/etc/os-release"
bash -n "$project_dir/os/mkosi.extra/etc/os-release"
[[ "$(rg -o 'systemd\.firstboot=no' "$project_dir/os/installer/grub.cfg" | wc -l | tr -d ' ')" == 3 ]]
rg -q 'menuentry "Dead Rose OS Installer \(debug\)"' "$project_dir/os/installer/grub.cfg"

rg -q 'test -f' "$project_dir/scripts/build-iso.sh"
rg -q 'stage-curtin.sh' "$project_dir/scripts/build-iso.sh"
rg -q 'backend-console.conf.*dead-rose-installer-backend.service.d/test-console.conf' "$project_dir/scripts/build-iso.sh"
rg -q 'rootfs\.tar\.gz' "$project_dir/scripts/build-os.sh"
rg -q -- '--create --gzip' "$project_dir/scripts/build-os.sh"
rg -q 'dead-rose-os.rootfs.tar.gz' "$project_dir/scripts/build-iso.sh"
rg -q 'stub-resolv\.conf.*installer_root/etc/resolv\.conf' "$project_dir/scripts/build-iso.sh"
rg -q '\[\[ -x .*dead-rose-installer' "$project_dir/tests/integration/installer-iso.sh"
rg -q 'DEAD_ROSE_INSTALLER_UI_READY' "$project_dir/tests/boot/installer-iso-smoke.sh"
rg -q 'DEAD_ROSE_INSTALL_COMPLETE' "$project_dir/tests/boot/installer-iso-smoke.sh"
rg -q 'DEAD_ROSE_SHELL_READY' "$project_dir/tests/boot/installer-iso-smoke.sh"
rg -q 'DEAD_ROSE_INSTALL_TIMEOUT_SECONDS:-5400' "$project_dir/tests/boot/installer-iso-smoke.sh"

echo "Repository runtime invariants pass."
