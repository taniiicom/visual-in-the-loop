#!/usr/bin/env bash
set -u
IMG="${1:-}"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "[visual-in-the-loop] show.sh: image not found: $IMG" >&2
    exit 0
fi

if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1 && command -v chafa >/dev/null 2>&1; then
    tmux split-window -h -d "chafa --size=80x40 '$IMG'; read -r _"
elif [ "${TERM_PROGRAM:-}" = "vscode" ] && command -v code >/dev/null 2>&1; then
    MD=$(mktemp -t vitl).md
    printf '![plan](%s)\n' "$IMG" > "$MD"
    code --reuse-window "$MD"
elif [ "$(uname -s)" = "Darwin" ]; then
    open "$IMG"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$IMG"
else
    echo "[visual-in-the-loop] no display path available for this environment" >&2
    exit 0
fi
