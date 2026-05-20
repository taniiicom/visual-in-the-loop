#!/usr/bin/env bash
# Render one or more images with chafa in the current tmux pane, with
# pagination.
#
# - chafa AUTO-DETECTS the terminal's graphics protocol (Kitty graphics in
#   Ghostty, sixel elsewhere, etc.). Do NOT force `-f` — forcing a protocol
#   turns chafa off the one that actually renders in the user's terminal.
# - Each image is shown at full pane width with its natural height. As many
#   images as fit the pane height go on one page; the rest paginate. Left /
#   Right arrows change page, Enter closes.
# - Nothing scrolls. Terminal graphics (Kitty / sixel) do not survive
#   scrolling into tmux's scrollback buffer — a scrolled image vanishes. So
#   each page is packed to fit the pane exactly. (This was the real bug: the
#   scrolling layout, not the graphics protocol.)
# - Pane size comes from `tmux display-message`, not `tput` (tput returns the
#   static 80x24 terminfo default when its stdout is captured).
# - Per-image cell height is measured with a `-f symbols` render: its line
#   count equals the cell rows a graphic render of the same image and width
#   occupies, so pages can be packed without overflowing (and scrolling).

set -u

PATHS=()
for arg in "$@"; do
    [ -f "$arg" ] && PATHS+=("$arg")
done
if [ "${#PATHS[@]}" -eq 0 ]; then
    echo "render-tmux-pane.sh: no valid image paths" >&2
    exit 1
fi

PAGE=0          # current page, 0-indexed
COLS=80
ROWS=24
HEIGHTS=()      # measured cell height of each image at COLS width
PAGEOF=()       # page index each image belongs to
PAGES=1

# Measure every image and pack them into pages that fit the pane.
measure() {
    COLS=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_width}' 2>/dev/null)
    ROWS=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_height}' 2>/dev/null)
    [ -z "$COLS" ] && COLS=80
    [ -z "$ROWS" ] && ROWS=24
    local avail=$((ROWS - 1))          # reserve one row for the footer
    [ "$avail" -lt 5 ] && avail=5

    local i h
    HEIGHTS=()
    for i in "${!PATHS[@]}"; do
        h=$(chafa -f symbols --size="${COLS}x9999" "${PATHS[$i]}" 2>/dev/null | wc -l)
        h=$((h))
        [ "$h" -lt 1 ] && h=1
        [ "$h" -gt "$avail" ] && h=$avail   # an over-tall image gets its own page
        HEIGHTS[$i]=$h
    done

    PAGEOF=()
    local pg=0 used=0 need
    for i in "${!PATHS[@]}"; do
        h=${HEIGHTS[$i]}
        if [ "$used" -eq 0 ]; then
            need=$h
        else
            need=$((1 + h))             # +1 for the gap row between images
        fi
        if [ "$used" -gt 0 ] && [ "$((used + need))" -gt "$avail" ]; then
            pg=$((pg + 1))
            used=0
            need=$h
        fi
        PAGEOF[$i]=$pg
        used=$((used + need))
    done
    PAGES=$((pg + 1))
}

# Render the images belonging to the current page.
render() {
    clear
    [ "$PAGE" -ge "$PAGES" ] && PAGE=$((PAGES - 1))
    [ "$PAGE" -lt 0 ] && PAGE=0
    local i first=1
    for i in "${!PATHS[@]}"; do
        if [ "${PAGEOF[$i]}" -eq "$PAGE" ]; then
            [ "$first" -eq 0 ] && echo
            first=0
            chafa --size="${COLS}x${HEIGHTS[$i]}" "${PATHS[$i]}"
        fi
    done
    if [ "$PAGES" -gt 1 ]; then
        printf -- '— page %d/%d · \xe2\x86\x90 / \xe2\x86\x92  page · Enter  close —' \
            "$((PAGE + 1))" "$PAGES"
    fi
}

reflow() { measure; render; }
trap reflow WINCH

measure
render

# Input loop: arrows change page, Enter closes. WINCH may interrupt read.
while true; do
    IFS= read -rsn1 key || continue
    case "$key" in
        "")
            break
            ;;
        $'\033')
            IFS= read -rsn2 -t 0.1 rest || rest=""
            case "$rest" in
                "[C") PAGE=$((PAGE + 1)); render ;;   # right arrow
                "[D") PAGE=$((PAGE - 1)); render ;;   # left arrow
            esac
            ;;
    esac
done
