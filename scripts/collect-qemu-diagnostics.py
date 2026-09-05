#!/usr/bin/env python3
"""Collect fixed, read-only appliance diagnostics over the QEMU serial console."""

from __future__ import annotations

import secrets
import socket
import sys
import time


END_MARKER_PREFIX = "DEAD_ROSE_DIAGNOSTICS_END_"
END_MARKER_NONCE = secrets.token_hex(16)
END_MARKER = END_MARKER_PREFIX + END_MARKER_NONCE
COMMAND = " ".join(
    (
        "printf '\\nDEAD_ROSE_DIAGNOSTICS_BEGIN\\n';",
        "systemctl --no-pager --full status dead-rose-core.service greetd.service;",
        "journalctl -b --no-pager -n 200 -u dead-rose-core.service -u greetd.service;",
        "journalctl -b -t dead-rose-session --no-pager -n 300;",
        "ls -la /dev/dri /run/dead-rose 2>&1;",
        "ps -ef | grep -E 'dead-rose|greetd|cage' | grep -v grep;",
        f"printf '\\n%s%s\\n' '{END_MARKER_PREFIX}' '{END_MARKER_NONCE}'",
    )
)

# kairos-init v0.17.2: 00_datasource.yaml, 02_agent.yaml,
# 09_systemd_services.yaml and 52_installer.yaml; agent v2.31.3 config get API.
# Keep the live profile and nonce handshake unchanged. Never print full configs:
# the install projection contains only the CI disk and lifecycle settings.
INSTALL_UNITS = (
    "kairos-installer.service kairos-agent.service kairos-webui.service "
    "kairos-interactive.service cos-setup-fs.service cos-setup-boot.service "
    "cos-setup-network.service"
)
INSTALL_COMMAND = " ".join(
    (
        "printf '\\nDEAD_ROSE_INSTALL_DIAGNOSTICS_BEGIN\\n';",
        "cat /proc/cmdline;",
        "lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,LABEL,MOUNTPOINTS; blkid;",
        "ls -la /dev/disk/by-label /dev/sr* 2>&1; findmnt;",
        "/usr/bin/kairos-agent --version;",
        f"systemctl --no-pager --full status {INSTALL_UNITS};",
        f"systemctl is-enabled {INSTALL_UNITS};",
        f"systemctl --no-pager cat {INSTALL_UNITS};",
        "journalctl -b --no-pager -o short-monotonic "
        + " ".join(f"-u {unit}" for unit in INSTALL_UNITS.split()) + ";",
        "journalctl -b --no-pager -t agent;",
        "tail -300 /var/log/kairos/agent.log 2>&1;",
        "ls -laR /run/cos; ls -l /run/.userdata_load 2>&1;",
        "find /system/oem /run/initramfs/live /etc/kairos "
        "/usr/local/cloud-config /oem -maxdepth 3 "
        "-type f \\( -name '*.yaml' -o -name '*.yml' -o -name user-data \\) -print;",
        "ls -la /oem/95_userdata 2>&1;",
        "printf '\\nDEAD_ROSE_INSTALL_CONFIG_SAFE_FIELDS\\n';",
        "timeout 10 /usr/bin/kairos-agent config get "
        "'install | {device: .device, auto: .auto, bind_mounts: .bind_mounts, "
        "reboot: .reboot, poweroff: .poweroff}';",
        f"printf '\\n%s%s\\n' '{END_MARKER_PREFIX}' '{END_MARKER_NONCE}'",
    )
)


def main() -> int:
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] != "install"):
        print("usage: collect-qemu-diagnostics.py SERIAL_SOCKET [install]", file=sys.stderr)
        return 2

    serial = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    serial.settimeout(1)
    deadline = time.monotonic() + 15
    while True:
        try:
            serial.connect(sys.argv[1])
            break
        except (FileNotFoundError, ConnectionRefusedError):
            if time.monotonic() >= deadline:
                print("QEMU serial socket did not become available", file=sys.stderr)
                return 1
            time.sleep(0.25)

    serial.sendall(b"\r")
    time.sleep(0.5)
    command = INSTALL_COMMAND if len(sys.argv) == 3 else COMMAND
    serial.sendall(command.encode() + b"\r")

    received = bytearray()
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        try:
            chunk = serial.recv(16 * 1024)
        except TimeoutError:
            continue
        if not chunk:
            break
        received.extend(chunk)
        # The complete nonce marker is absent from the echoed command and only
        # appears after every diagnostic command has completed.
        if END_MARKER.encode() in received:
            time.sleep(0.5)
            return 0

    print("Guest diagnostics did not complete", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
