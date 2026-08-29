#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
command -v rg >/dev/null || { echo "MISSING rg: install ripgrep (https://github.com/BurntSushi/ripgrep)" >&2; exit 1; }
required=(VERSION DESIGN.md os/mkosi.conf os/mkosi.repart/10-esp.conf os/mkosi.repart/20-root-a.conf os/mkosi.repart/30-root-b.conf os/mkosi.repart/40-state.conf os/systemd/dead-rose-core.service os/systemd/dead-rose-graphical.service apps/shell/src-tauri/tauri.conf.json apps/installer/src-tauri/tauri.conf.json)
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
      in_pkglist = (setting ~ /^(Packages|BuildPackages|VolatilePackages|ToolsTreePackages|PackageDirectories)$/)
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
if ! rg -q 'sudo mksquashfs' "$iso_build"; then
  echo "mksquashfs must run with privileges so privileged files and ownership are preserved" >&2
  exit 1
fi
if ! rg -q 'squashfs\.sh' "$iso_build"; then
  echo "build-iso.sh must validate the squashfs after packing" >&2
  exit 1
fi
for pattern in 'vmlinuz-\*' 'initrd\.img-\*'; do
  if ! rg -q "resolve_single_boot_artifact.*'$pattern'|'$pattern'" "$iso_build"; then
    echo "build-iso.sh must resolve the $pattern boot artifact deterministically" >&2
    exit 1
  fi
done
if ! rg -q 'sudo find .*search_root' "$iso_build"; then
  echo "boot artifact discovery must be privileged because mkosi protects Ubuntu boot directories" >&2
  exit 1
fi
for artifact in kernel initrd; do
  if ! rg -q "sudo install .*\\\$$artifact" "$iso_build"; then
    echo "the $artifact must be copied from the privileged installer root with sudo install" >&2
    exit 1
  fi
done
if rg -q 'sort +\|\s*tail|tail\s+-n\s*1' "$iso_build"; then
  echo "boot artifact discovery must not use sort|tail, which silently returns empty or ambiguous matches" >&2
  exit 1
fi
squashfs_test="$project_dir/tests/integration/squashfs.sh"
[[ -x "$squashfs_test" ]] || { echo "squashfs regression test is missing or not executable: $squashfs_test" >&2; exit 1; }
rg -q 'etc/shadow' "$squashfs_test" || { echo "squashfs regression test must assert presence of /etc/shadow" >&2; exit 1; }
rg -q 'etc/gshadow' "$squashfs_test" || { echo "squashfs regression test must assert presence of /etc/gshadow" >&2; exit 1; }

echo "Repository invariants pass."
