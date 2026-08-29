#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
required=(VERSION DESIGN.md os/mkosi.conf os/mkosi.repart/10-esp.conf os/mkosi.repart/20-root-a.conf os/mkosi.repart/30-root-b.conf os/mkosi.repart/40-state.conf os/systemd/dead-rose-core.service os/systemd/dead-rose-graphical.service apps/shell/src-tauri/tauri.conf.json apps/installer/src-tauri/tauri.conf.json)
for path in "${required[@]}"; do [[ -f "$project_dir/$path" ]] || { echo "Missing $path" >&2; exit 1; }; done
if rg -n "localStorage|sessionStorage|run_command|Command::new\(.*sh" "$project_dir/apps" "$project_dir/crates"; then echo "Forbidden runtime pattern found" >&2; exit 1; fi
if rg -n '^Output=.*[/\\]' "$project_dir/os" --glob mkosi.conf; then echo "mkosi Output must be a filename without path components" >&2; exit 1; fi
echo "Repository invariants pass."
