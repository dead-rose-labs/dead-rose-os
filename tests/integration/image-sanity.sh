#!/usr/bin/env bash
set -euo pipefail

grep -Eq '^(VERSION_ID|UBUNTU_VERSION)="?26\.04' /etc/os-release
test -s /etc/kairos-release
test -x /opt/dead-rose/bin/dead-rose-core
test -x /opt/dead-rose/bin/dead-rose-shell
test -x /usr/bin/cage
test -x /usr/sbin/agreety
runuser -u deadrose -- test -x /opt/dead-rose/bin/dead-rose-shell
runuser -u deadrose -- test -x /usr/bin/cage
shell_dependencies=$(ldd /opt/dead-rose/bin/dead-rose-shell)
cage_dependencies=$(ldd /usr/bin/cage)
if grep -Fq 'not found' <<< "${shell_dependencies}"; then
  printf 'dead-rose-shell has unresolved runtime dependencies\n' >&2
  exit 1
fi
if grep -Fq 'not found' <<< "${cage_dependencies}"; then
  printf 'cage has unresolved runtime dependencies\n' >&2
  exit 1
fi
test -f /etc/systemd/system/dead-rose-core.service
test "$(readlink /etc/systemd/system/multi-user.target.wants/dead-rose-core.service)" = /etc/systemd/system/dead-rose-core.service
test "$(readlink /etc/systemd/system/multi-user.target.wants/NetworkManager.service)" = /usr/lib/systemd/system/NetworkManager.service
test ! -e /etc/systemd/system/multi-user.target.wants/greetd.service
test "$(readlink /etc/systemd/system/graphical.target.wants/greetd.service)" = /usr/lib/systemd/system/greetd.service
test "$(readlink /etc/systemd/system/display-manager.service)" = /usr/lib/systemd/system/greetd.service
test "$(readlink /etc/systemd/system/default.target)" = /usr/lib/systemd/system/graphical.target
test -f /etc/greetd/config.toml
python3 - <<'PY'
import tomllib

with open("/etc/greetd/config.toml", "rb") as config_file:
    config = tomllib.load(config_file)

initial = config["initial_session"]
fallback = config["default_session"]
assert initial["user"] == "deadrose"
assert "/usr/bin/cage" in initial["command"]
assert "/opt/dead-rose/bin/dead-rose-shell" in initial["command"]
assert fallback["user"] == "_greetd"
assert "/usr/sbin/agreety" in fallback["command"]
assert "dead-rose-shell" not in fallback["command"]
PY
test "$(id -u deadrose)" -ne 0
getent passwd _greetd >/dev/null
id -nG deadrose | tr ' ' '\n' | grep -Fxq video
if getent group render >/dev/null; then
  id -nG deadrose | tr ' ' '\n' | grep -Fxq render
fi
test -s /etc/default/locale
# shellcheck source=/dev/null
. /etc/default/locale
test "${LANG}" = C.UTF-8
LANG="${LANG}" locale charmap | grep -Fxq UTF-8
grep -Fq 'Conflicts=getty@tty1.service' /etc/systemd/system/greetd.service.d/dead-rose.conf
awk -F: '$2 !~ /^(!|\*)/ { exit 1 }' /etc/shadow
! dpkg-query -W ubuntu-desktop gdm3 2>/dev/null
