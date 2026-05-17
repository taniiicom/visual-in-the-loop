#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMG=$(node "$SCRIPT_DIR/generate.mjs")
GEN_STATUS=$?
if [ $GEN_STATUS -ne 0 ] || [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "[visual-in-the-loop] generation failed, continuing without visual" >&2
    exit 0
fi

bash "$SCRIPT_DIR/show.sh" "$IMG" || true
echo "[visual-in-the-loop] rendered: $IMG"
