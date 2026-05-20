#!/usr/bin/env bash
# Render one or more images with chafa in the current pane.
# - Re-renders on SIGWINCH so it stays correct across tmux pane / window resizes.
# - With multiple images: ← / → cycles, Enter closes.
# - With a single image: Enter closes.

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
CURRENT=0

render() {
    clear
    chafa "${PATHS[$CURRENT]}"
    if [ "$TOTAL" -gt 1 ]; then
        printf '\n[%d/%d]  ← / →  navigate · Enter  close' \
            "$((CURRENT + 1))" "$TOTAL"
    fi
}

trap render WINCH
render

while true; do
    IFS= read -rsn1 key || continue
    case "$key" in
        "")
            # Enter — exit
            break
            ;;
        $'\033')
            # ESC sequence — likely an arrow key
            IFS= read -rsn2 -t 0.1 rest || rest=""
            case "$rest" in
                "[C")  # right
                    CURRENT=$(( (CURRENT + 1) % TOTAL ))
                    render
                    ;;
                "[D")  # left
                    CURRENT=$(( (CURRENT - 1 + TOTAL) % TOTAL ))
                    render
                    ;;
            esac
            ;;
    esac
done
