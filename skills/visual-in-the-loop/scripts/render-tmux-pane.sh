#!/usr/bin/env bash
# Render one or more images stacked vertically with chafa, dividing the pane
# height evenly among them. Re-renders on SIGWINCH so it stays correct across
# tmux pane / window resizes. Press Enter (in the pane) to close.

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
    local cols rows per_rows i
    cols=$(tput cols)
    rows=$(tput lines)
    # chafa ends every render with a trailing newline. If the output reaches
    # the last pane row, that newline scrolls the pane and clips the top of
    # the image. Reserve one row per image so the stacked output always fits
    # within the pane height.
    per_rows=$(( (rows - TOTAL) / TOTAL ))
    [ "$per_rows" -lt 5 ] && per_rows=5
    for i in "${!PATHS[@]}"; do
        chafa --size=${cols}x${per_rows} "${PATHS[$i]}"
        if [ "$i" -lt "$((TOTAL - 1))" ]; then
            echo
        fi
    done
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
