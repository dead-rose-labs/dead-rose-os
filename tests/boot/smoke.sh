#!/usr/bin/env bash
set -euo pipefail
image="${1:?usage: smoke.sh IMAGE}"
[[ -f "$image" ]] || { echo "Image not found: $image" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "qemu-system-x86_64 is required" >&2; exit 1; }
echo "Boot smoke test requires the CI serial marker service and is run by the privileged image workflow."
