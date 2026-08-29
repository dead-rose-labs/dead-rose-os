#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

echo "Repository invariants pass."
