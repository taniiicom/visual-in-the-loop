#!/usr/bin/env bash
# Read TSV (path<TAB>title) from stdin and render all images to the user's
# environment.
#
# VITL_DISPLAY (env var):
#   auto    (default) — pick the first available: tmux+chafa → vscode → open → xdg-open
#   tmux    — force tmux+chafa, fall back to auto if not available
#   vscode  — force VS Code markdown tab, fall back to auto if not available
#   open    — force OS image viewer (open / xdg-open), fall back to auto if not available
#   none    — skip display entirely (images still generated)

set -u
SHOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PATHS=()
TITLES=()
while IFS=$'\t' read -r p t; do
    if [ -n "$p" ] && [ -f "$p" ]; then
        PATHS+=("$p")
        TITLES+=("${t:-}")
    fi
done

if [ "${#PATHS[@]}" -eq 0 ]; then
    echo "[visual-in-the-loop] show.sh: no images to display" >&2
    exit 0
fi

DISPLAY_PREF="$(echo "${VITL_DISPLAY:-auto}" | tr '[:upper:]' '[:lower:]')"

try_tmux() {
    if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1 && command -v chafa >/dev/null 2>&1; then
        # Build a quoted arg list for the render script
        local args=""
        local p
        for p in "${PATHS[@]}"; do
            args+="'${p//\'/\'\\\'\'}' "
        done
        tmux split-window -h -d "bash '$SHOW_DIR/render-tmux-pane.sh' $args"
        return 0
    fi
    return 1
}

try_vscode() {
    if [ "${TERM_PROGRAM:-}" = "vscode" ] && command -v code >/dev/null 2>&1; then
        local md
        md=$(mktemp -t vitl).md
        local i
        for i in "${!PATHS[@]}"; do
            if [ -n "${TITLES[$i]}" ]; then
                printf '## %s\n\n' "${TITLES[$i]}" >> "$md"
            fi
            printf '![](%s)\n\n' "${PATHS[$i]}" >> "$md"
        done
        code --reuse-window "$md"
        return 0
    fi
    return 1
}

try_open() {
    if [ "$(uname -s)" = "Darwin" ]; then
        open "${PATHS[@]}"
        return 0
    elif command -v xdg-open >/dev/null 2>&1; then
        local p
        for p in "${PATHS[@]}"; do
            xdg-open "$p"
        done
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
        # auto and any unrecognized value
        auto
        ;;
esac
