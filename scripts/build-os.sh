#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
output_directory="$project_dir/build"
output_name="dead-rose-os-${version}-amd64.raw"
output="$output_directory/$output_name"
staging="$output_directory/os-extra"
mkdir -p "$project_dir/build/logs"
cd "$project_dir"
corepack pnpm install --frozen-lockfile
corepack pnpm build
cargo build --release --locked -p dead-rose-core -p dead-rose-shell -p dead-rose-session --bins
if [[ "$staging" != "$project_dir/build/os-extra" ]]; then echo "Refusing unsafe staging target" >&2; exit 1; fi
find "$staging" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
install -Dm755 target/release/dead-rose-core "$staging/usr/lib/dead-rose/dead-rose-core"
install -Dm755 target/release/dead-rose-shell "$staging/usr/lib/dead-rose/dead-rose-shell"
install -Dm755 target/release/dead-rose-session "$staging/usr/lib/dead-rose/dead-rose-session"
install -Dm755 target/release/dead-rose-state-init "$staging/usr/lib/dead-rose/dead-rose-state-init"
install -Dm644 os/sysusers/dead-rose.conf "$staging/usr/lib/sysusers.d/dead-rose.conf"
install -Dm644 os/tmpfiles/dead-rose.conf "$staging/usr/lib/tmpfiles.d/dead-rose.conf"
install -Dm644 os/systemd/dead-rose-core.service "$staging/usr/lib/systemd/system/dead-rose-core.service"
install -Dm644 os/systemd/dead-rose-state-init.service "$staging/usr/lib/systemd/system/dead-rose-state-init.service"
install -Dm644 os/systemd/dead-rose-state.mount "$staging/usr/lib/systemd/system/var-lib-dead\x2drose.mount"
install -Dm644 os/greetd/installed.toml "$staging/etc/greetd/config.toml"
install -Dm644 os/systemd/greetd-installed.conf "$staging/etc/systemd/system/greetd.service.d/dead-rose.conf"
install -Dm644 os/grub/99-dead-rose.cfg "$staging/etc/default/grub.d/99-dead-rose.cfg"
install -Dm644 os/plymouth/dead-rose/dead-rose.plymouth "$staging/usr/share/plymouth/themes/dead-rose/dead-rose.plymouth"
install -Dm644 os/plymouth/dead-rose/dead-rose.script "$staging/usr/share/plymouth/themes/dead-rose/dead-rose.script"
install -Dm644 assets/brand/dead-rose-os-logo.png "$staging/usr/share/plymouth/themes/dead-rose/dead-rose-os-logo.png"
mkdir -p "$staging/etc/systemd/system/graphical.target.wants" "$staging/etc/systemd/system/multi-user.target.wants" "$staging/etc/systemd/system/local-fs.target.wants" "$staging/usr/share/plymouth/themes"
ln -sf /usr/lib/systemd/system/greetd.service "$staging/etc/systemd/system/graphical.target.wants/greetd.service"
ln -sf /usr/lib/systemd/system/dead-rose-core.service "$staging/etc/systemd/system/multi-user.target.wants/dead-rose-core.service"
ln -sf /usr/lib/systemd/system/dead-rose-state-init.service "$staging/etc/systemd/system/multi-user.target.wants/dead-rose-state-init.service"
ln -sf '/usr/lib/systemd/system/var-lib-dead\x2drose.mount' "$staging/etc/systemd/system/local-fs.target.wants/var-lib-dead\x2drose.mount"
ln -sf /usr/lib/systemd/system/graphical.target "$staging/etc/systemd/system/default.target"
ln -sf /usr/share/plymouth/themes/dead-rose/dead-rose.plymouth "$staging/usr/share/plymouth/themes/default.plymouth"
if [[ "${DEAD_ROSE_TEST_MARKERS:-0}" == "1" ]]; then
  install -Dm755 tests/boot/assets/session-ready "$staging/usr/lib/dead-rose-tests/session-ready"
  install -Dm644 tests/boot/assets/installed-session-ready.service "$staging/usr/lib/systemd/system/dead-rose-session-ready.service"
  ln -sf /usr/lib/systemd/system/dead-rose-session-ready.service "$staging/etc/systemd/system/graphical.target.wants/dead-rose-session-ready.service"
fi
mkosi --directory os --output-directory "$output_directory" --output "$output_name" --extra-tree "$staging" summary
sudo mkosi --directory os --output-directory "$output_directory" --output "$output_name" --extra-tree "$staging" build 2>&1 | tee "$project_dir/build/logs/mkosi.log"
sudo chown -- "$(id -u):$(id -g)" "$output"
sha256sum "$output" > "$output.sha256"
zstd -T0 -19 --force "$output" -o "$output.zst"
