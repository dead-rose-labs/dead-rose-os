#!/usr/bin/env bash
set -Eeuo pipefail
directory=${1:?Missing package directory}
cd -- "$directory"
makepkg --cleanbuild --noconfirm --log
