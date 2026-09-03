#!/usr/bin/env bash
set -euo pipefail

grep -Eq '^(VERSION_ID|UBUNTU_VERSION)="?26\.04' /etc/os-release
test -s /etc/kairos-release
test -x /opt/dead-rose/bin/dead-rose-core
test -x /opt/dead-rose/bin/dead-rose-shell
test -f /etc/systemd/system/dead-rose-core.service
test -f /etc/greetd/config.toml
grep -Fq 'user = "deadrose"' /etc/greetd/config.toml
awk -F: '$2 !~ /^(!|\*)/ { exit 1 }' /etc/shadow
! dpkg-query -W ubuntu-desktop gdm3 2>/dev/null
