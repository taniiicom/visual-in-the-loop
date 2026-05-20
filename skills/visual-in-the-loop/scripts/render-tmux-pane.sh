#!/usr/bin/env bash
# Render a single image with chafa in the current tmux pane, sized to fit.
#
# - chafa AUTO-DETECTS the terminal's graphics protocol (Kitty graphics in
#   Ghostty, sixel elsewhere, etc.). Do NOT force `-f` — forcing a protocol
#   turns chafa off the one that actually renders in the user's terminal.
# - The image is sized to fit within the pane. Nothing scrolls: terminal
#   graphics do not survive scrolling into tmux's scrollback buffer.
# - Re-renders on SIGWINCH so it stays correct across pane / window resizes.
# - Press Enter (in the pane) to close.
#
# Pane size comes from `tmux display-message`, not `tput`: tput returns the
# static 80x24 terminfo default when its stdout is captured.

set -u
IMG="${1:-}"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "render-tmux-pane.sh: missing or invalid image path: $IMG" >&2
    exit 1
fi

render() {
    clear
    local cols rows
    cols=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_width}' 2>/dev/null)
    rows=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_height}' 2>/dev/null)
    [ -z "$cols" ] && cols=80
    [ -z "$rows" ] && rows=24
    # Reserve one row for chafa's trailing newline so the top is not scrolled
    # off; the image fits within the pane, so nothing scrolls.
    chafa --size="${cols}x$((rows - 1))" "$IMG"
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
