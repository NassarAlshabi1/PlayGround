#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p test -n "${CAPTURE_URL:?Set CAPTURE_URL.}"
/usr/bin/time -p test -n "${CAPTURE_DIR:?Set CAPTURE_DIR.}"
/usr/bin/time -p node "${RUNTIME_DIR:?}/scripts/default-capture.mjs"
