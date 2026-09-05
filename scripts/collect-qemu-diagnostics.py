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


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: collect-qemu-diagnostics.py SERIAL_SOCKET", file=sys.stderr)
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
    serial.sendall(COMMAND.encode() + b"\r")

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
