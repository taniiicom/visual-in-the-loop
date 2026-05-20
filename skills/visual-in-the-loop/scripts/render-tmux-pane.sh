#!/usr/bin/env bash
# Render one or more images with chafa in the current pane.
# - Single image: fit entirely within the pane (no scrolling needed).
# - Multiple images: each at full pane width with natural height, stacked
#   vertically. The total can exceed the pane height — scroll with tmux
#   copy-mode (Ctrl-b [ then arrows / PageUp) to see them all.
# - Re-renders on SIGWINCH so it stays correct across tmux pane / window
#   resizes.
# - Press Enter (in the pane) to close.

set -u

PATHS=()
for arg in "$@"; do
    if [ -f "$arg" ]; then
        PATHS+=("$arg")
    fi
done

if [ "${#PATHS[@]}" -eq 0 ]; then
    echo "render-tmux-pane.sh: no valid image paths" >&2
    exit 1
fi

TOTAL=${#PATHS[@]}

render() {
    clear
    # Drop stale scrollback from earlier renders (e.g. before a resize) so
    # scrolling only ever shows the current set of images.
    [ -n "${TMUX_PANE:-}" ] && tmux clear-history -t "$TMUX_PANE" 2>/dev/null
    local cols rows i
    cols=$(tput cols)
    rows=$(tput lines)
    if [ "$TOTAL" -eq 1 ]; then
        # Fit the whole image within the pane. Reserve 1 row for chafa's
        # trailing newline so the top is not scrolled off.
        chafa --size="${cols}x$((rows - 1))" "${PATHS[0]}"
    else
        # Full pane width, natural height, stacked vertically. Total height
        # may exceed the pane; the user scrolls to see everything.
        for i in "${!PATHS[@]}"; do
            chafa --size="${cols}x9999" "${PATHS[$i]}"
            echo
        done
        printf -- '— %d images · scroll up to see all · Enter to close —' "$TOTAL"
    fi
}

trap render WINCH
render

# Block until the user presses Enter. WINCH may interrupt `read`; if so the
# read returns non-zero and we loop to wait again.
while true; do
    if read -r _; then
        break
    fi
done
