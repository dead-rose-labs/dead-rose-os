#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=ci/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
stage=${1:?Missing job stage}
outcome=${2:?Missing job outcome}
printf '%s\n' "$outcome" > "$ARTIFACTS/status/github-$stage"
python3 - "$stage" <<'PY'
import json, os, pathlib, sys
context = {k.lower(): os.environ.get(k, '') for k in ('GIT_COMMIT', 'ARCH_SNAPSHOT', 'CALAMARES_COMMIT', 'ARCH_CONTAINER_DIGEST', 'GITHUB_RUN_ID')}
(pathlib.Path(os.environ['ARTIFACTS']) / 'manifest' / ('context-' + sys.argv[1] + '.json')).write_text(json.dumps(context, indent=2))
PY
"$FACTORY_ROOT/ci/summary.sh"
