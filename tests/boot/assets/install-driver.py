#!/usr/bin/python3
import json
import socket
import sys
import time

socket_path = "/run/dead-rose-installer/backend.sock"
stable_id = "/dev/disk/by-id/virtio-deadrose-smoke"

for _ in range(180):
    try:
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.connect(socket_path)
        break
    except OSError:
        time.sleep(1)
else:
    raise SystemExit("installer backend socket did not become ready")

request = {
    "operation": "install",
    "stable_id": stable_id,
    "hostname": "dead-rose-smoke",
    "username": "smoke-admin",
    "password": "smoke-test-password-only",
    "confirmation": "ERASE",
}
client.sendall(json.dumps(request).encode("utf-8") + b"\n")
stream = client.makefile("r", encoding="utf-8")
for line in stream:
    response = json.loads(line)
    status = response.get("status")
    if status == "progress":
        print("DEAD_ROSE_INSTALL_PROGRESS " + response.get("phase", "unknown"), flush=True)
    elif status == "complete":
        print("DEAD_ROSE_INSTALL_COMPLETE", flush=True)
        sys.exit(0)
    elif status == "error":
        raise SystemExit("installer backend failed: " + response.get("code", "unknown"))

raise SystemExit("installer backend disconnected before completion")

