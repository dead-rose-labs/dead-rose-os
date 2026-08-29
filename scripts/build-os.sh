#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
output="$project_dir/build/dead-rose-os-${version}-amd64.raw"
mkdir -p "$project_dir/build/logs"
cd "$project_dir"
pnpm install --frozen-lockfile
pnpm build
cargo build --release --locked -p dead-rose-core -p dead-rose-shell
install -Dm755 target/release/dead-rose-core os/mkosi.extra/usr/lib/dead-rose/dead-rose-core
install -Dm755 target/release/dead-rose-shell os/mkosi.extra/usr/lib/dead-rose/dead-rose-shell
install -Dm644 os/sysusers/dead-rose.conf os/mkosi.extra/usr/lib/sysusers.d/dead-rose.conf
install -Dm644 os/tmpfiles/dead-rose.conf os/mkosi.extra/usr/lib/tmpfiles.d/dead-rose.conf
install -Dm644 os/systemd/dead-rose-core.service os/mkosi.extra/usr/lib/systemd/system/dead-rose-core.service
install -Dm644 os/systemd/dead-rose-graphical.service os/mkosi.extra/usr/lib/systemd/system/dead-rose-graphical.service
install -Dm644 os/systemd/dead-rose-state.mount os/mkosi.extra/usr/lib/systemd/system/var-lib-dead\x2drose.mount
install -Dm644 os/plymouth/dead-rose/dead-rose.plymouth os/mkosi.extra/usr/share/plymouth/themes/dead-rose/dead-rose.plymouth
install -Dm644 os/plymouth/dead-rose/dead-rose.script os/mkosi.extra/usr/share/plymouth/themes/dead-rose/dead-rose.script
install -Dm644 assets/brand/dead-rose-os-logo.png os/mkosi.extra/usr/share/plymouth/themes/dead-rose/dead-rose-os-logo.png
mkdir -p os/mkosi.extra/etc/systemd/system/graphical.target.wants os/mkosi.extra/etc/systemd/system/local-fs.target.wants os/mkosi.extra/usr/share/plymouth/themes
ln -sf /usr/lib/systemd/system/dead-rose-core.service os/mkosi.extra/etc/systemd/system/graphical.target.wants/dead-rose-core.service
ln -sf /usr/lib/systemd/system/dead-rose-graphical.service os/mkosi.extra/etc/systemd/system/graphical.target.wants/dead-rose-graphical.service
ln -sf '/usr/lib/systemd/system/var-lib-dead\x2drose.mount' 'os/mkosi.extra/etc/systemd/system/local-fs.target.wants/var-lib-dead\x2drose.mount'
ln -sf /usr/share/plymouth/themes/dead-rose/dead-rose.plymouth os/mkosi.extra/usr/share/plymouth/themes/default.plymouth
mkosi --directory os --output "$output" build 2>&1 | tee "$project_dir/build/logs/mkosi.log"
sha256sum "$output" > "$output.sha256"
zstd -T0 -19 --force "$output" -o "$output.zst"
