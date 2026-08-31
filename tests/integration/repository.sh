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
  os/systemd/dead-rose-state-init.service os/systemd/dead-rose-state.mount
  os/grub/99-dead-rose.cfg os/installer/grub.cfg
  crates/session/src/main.rs crates/installer-agent/src/main.rs
  docs/architecture/rebuild-audit.md docs/architecture/os-runtime.md docs/build.md docs/debug.md
  tests/boot/smoke.sh tests/boot/installer-iso-smoke.sh
)
for path in "${required[@]}"; do [[ -f "$project_dir/$path" ]] || { echo "Missing $path" >&2; exit 1; }; done

for obsolete in os/systemd/dead-rose-graphical.service os/systemd/dead-rose-installer.service os/cage/environment; do
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

rg -q '^Bootloader=grub$' "$project_dir/os/mkosi.conf"
rg -q '^[[:space:]]+greetd$' "$project_dir/os/mkosi.conf"
rg -q '^[[:space:]]+greetd$' "$project_dir/os/installer/mkosi.conf"
rg -q '^[[:space:]]+login$' "$project_dir/os/mkosi.conf"
rg -q '^[[:space:]]+login$' "$project_dir/os/installer/mkosi.conf"
if rg -q '^[[:space:]]+curtin$' "$project_dir/os/installer/mkosi.conf"; then
  echo "Ubuntu 26.04 does not ship a curtin binary package; use the pinned source runtime" >&2
  exit 1
fi
rg -q '^curtin_commit="[0-9a-f]{40}"$' "$project_dir/scripts/stage-curtin.sh"
rg -q '^curtin_sha256="[0-9a-f]{64}"$' "$project_dir/scripts/stage-curtin.sh"
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
rg -q '^u deadrose-ui .*nologin$' "$project_dir/os/sysusers/dead-rose.conf"
rg -q '^u deadrose-installer .*nologin$' "$project_dir/os/sysusers/dead-rose.conf"
if rg -q '^m deadrose-(ui|installer) (video|render|input)$' "$project_dir/os/sysusers/dead-rose.conf"; then
  echo "greetd/logind sessions must not require permanent device-group membership" >&2
  exit 1
fi
rg -q '^User=root$' "$project_dir/os/systemd/dead-rose-installer-backend.service"
rg -q '^Group=deadrose-installer-ipc$' "$project_dir/os/systemd/dead-rose-installer-backend.service"

rg -q 'InstallerRequest::Install' "$project_dir/apps/installer/src-tauri/src/main.rs"
rg -q 'UnixStream::connect' "$project_dir/apps/installer/src-tauri/src/main.rs"
if rg -q 'dead-rose-installer-core|nix.workspace' "$project_dir/apps/installer/src-tauri/Cargo.toml"; then
  echo "Installer Tauri process must not contain privileged disk implementation" >&2
  exit 1
fi
rg -q 'Command::new\("/usr/bin/curtin"\)' "$project_dir/crates/installer-agent/src/main.rs"
rg -q '/dev/disk/by-id' "$project_dir/crates/installer-agent/src/main.rs"
rg -q 'PARTNAME=STATE' "$project_dir/crates/installer-agent/src/main.rs"
rg -q 'installation_in_progress' "$project_dir/crates/installer-agent/src/main.rs"
rg -q 'repair_state_ownership' "$project_dir/crates/session/src/bin/dead-rose-state-init.rs"
rg -q 'tracing_journald::layer' "$project_dir/crates/session/src/main.rs"
rg -q 'relay_output\("cage stderr"' "$project_dir/crates/session/src/main.rs"
rg -q 'journalctl .*_UID=' "$project_dir/tests/boot/assets/smoke-diagnostics"

rg -q '^ID=deadrose$' "$project_dir/os/mkosi.extra/etc/os-release"
rg -q '^UBUNTU_CODENAME=resolute$' "$project_dir/os/mkosi.extra/etc/os-release"
[[ "$(rg -o 'systemd\.firstboot=no' "$project_dir/os/installer/grub.cfg" | wc -l | tr -d ' ')" == 3 ]]
rg -q 'menuentry "Dead Rose OS Installer \(debug\)"' "$project_dir/os/installer/grub.cfg"

rg -q 'test -f' "$project_dir/scripts/build-iso.sh"
rg -q 'stage-curtin.sh' "$project_dir/scripts/build-iso.sh"
rg -q '\[\[ -x .*dead-rose-installer' "$project_dir/tests/integration/installer-iso.sh"
rg -q 'DEAD_ROSE_INSTALLER_UI_READY' "$project_dir/tests/boot/installer-iso-smoke.sh"
rg -q 'DEAD_ROSE_INSTALL_COMPLETE' "$project_dir/tests/boot/installer-iso-smoke.sh"
rg -q 'DEAD_ROSE_SHELL_READY' "$project_dir/tests/boot/installer-iso-smoke.sh"

echo "Repository runtime invariants pass."
