#!/usr/bin/env bash
# Render an image with chafa in the current terminal, filling the pane.
# Re-render on SIGWINCH so it stays correct across tmux pane resizes.
# Press Enter (in the pane) to close.

set -u
IMG="${1:-}"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "render-tmux-pane.sh: missing or invalid image path: $IMG" >&2
    exit 1
fi

render() {
    clear
    # No --size: chafa auto-detects terminal/pane size and fills it,
    # preserving aspect ratio.
    chafa "$IMG"
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
