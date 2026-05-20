#!/usr/bin/env bash
# Render a single image to the user's environment.
#
# VITL_DISPLAY (env var):
#   auto    (default) — pick the first available: tmux+chafa -> vscode -> open
#   tmux    — force tmux+chafa, fall back to auto if not available
#   vscode  — force VS Code markdown tab, fall back to auto if not available
#   open    — force OS image viewer (open / xdg-open), fall back to auto
#   none    — skip display entirely (the image is still generated)

set -u
SHOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG="${1:-}"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "[visual-in-the-loop] show.sh: image not found: $IMG" >&2
    exit 0
fi

DISPLAY_PREF="$(echo "${VITL_DISPLAY:-auto}" | tr '[:upper:]' '[:lower:]')"

try_tmux() {
    if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1 && command -v chafa >/dev/null 2>&1; then
        tmux split-window -h -d "bash '$SHOW_DIR/render-tmux-pane.sh' '$IMG'"
        return 0
    fi
    return 1
}

try_vscode() {
    if [ "${TERM_PROGRAM:-}" = "vscode" ] && command -v code >/dev/null 2>&1; then
        local md
        md=$(mktemp -t vitl).md
        printf '![plan](%s)\n' "$IMG" > "$md"
        code --reuse-window "$md"
        return 0
    fi
    return 1
}

try_open() {
    if [ "$(uname -s)" = "Darwin" ]; then
        open "$IMG"
        return 0
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$IMG"
        return 0
    fi
    return 1
}

auto() {
    try_tmux && return 0
    try_vscode && return 0
    try_open && return 0
    echo "[visual-in-the-loop] no display path available for this environment" >&2
    return 0
}

case "$DISPLAY_PREF" in
    none)
        exit 0
        ;;
    tmux)
        if try_tmux; then exit 0; fi
        echo "[visual-in-the-loop] VITL_DISPLAY=tmux requested but unavailable, falling back to auto" >&2
        auto
        ;;
    vscode)
        if try_vscode; then exit 0; fi
        echo "[visual-in-the-loop] VITL_DISPLAY=vscode requested but unavailable, falling back to auto" >&2
        auto
        ;;
    open)
        if try_open; then exit 0; fi
        echo "[visual-in-the-loop] VITL_DISPLAY=open requested but unavailable, falling back to auto" >&2
        auto
        ;;
    *)
        auto
        ;;
esac
