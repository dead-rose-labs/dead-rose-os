#!/usr/bin/env bash
# Releng-derived profile. See docs/architecture.md for upstream references.
# shellcheck disable=SC2034
iso_name="dead-rose-os"
iso_label="DEADROSE_010"
iso_publisher="Dead Rose Labs"
iso_application="Dead Rose OS Live Desktop"
iso_version="0.1.0"
install_dir="arch"
arch="x86_64"
buildmodes=('iso')
bootmodes=('uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d/10-live"]="0:0:440"
  ["/home/live"]="1000:1000:750"
  ["/home/live/.config"]="1000:1000:750"
  ["/home/live/.config/menus"]="1000:1000:750"
  ["/home/live/.config/kdeglobals"]="1000:1000:644"
  ["/home/live/.config/plasmarc"]="1000:1000:644"
  ["/home/live/.config/kwinrc"]="1000:1000:644"
  ["/home/live/.config/kcminputrc"]="1000:1000:644"
  ["/home/live/.config/konsolerc"]="1000:1000:644"
  ["/home/live/.config/menus/plasma-applications.menu"]="1000:1000:644"
  ["/usr/local/bin/dead-rose-live-check"]="0:0:755"
  ["/usr/local/bin/install-dead-rose"]="0:0:755"
)
