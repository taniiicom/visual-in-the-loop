#!/usr/bin/env bash
# Entry point: master switch -> trigger filter -> generate -> show.
#
# Env vars (all optional):
#   VITL_ENABLED   master switch. 0/false/no/off (case-insensitive) disables.
#                  Unset or anything else -> enabled.
#   VITL_TRIGGER   comma-separated allowed triggers (e.g. "plan,clarify") or
#                  "all". Default: all.
#
# Argv (optional, any order):
#   --trigger <type>   one of plan / clarify / decision, passed by the agent.
#                      If omitted, the skill still fires (fail-safe).
#   --lang <language>  the language the conversation is being held in (e.g.
#                      "Japanese"). The diagram's text is rendered in it.
#                      Overrides the VITL_LANG env var. If neither is given,
#                      the model uses the plan text's own language.
#
# Stdin: the plain text to visualize (a plan, a question with its options,
# etc.). It is passed to the model verbatim — pipe the real text, not a
# rewritten or summarized version of it.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Master switch
case "$(echo "${VITL_ENABLED:-}" | tr '[:upper:]' '[:lower:]')" in
    0|false|no|off)
        exit 0
        ;;
esac

# 2. Parse optional args: --trigger <type>, --lang <language> (any order)
TRIGGER=""
LANG_VALUE="${VITL_LANG:-}"
while [ $# -gt 0 ]; do
    case "$1" in
        --trigger)
            TRIGGER="${2:-}"
            shift; [ $# -gt 0 ] && shift
            ;;
        --lang)
            LANG_VALUE="${2:-}"
            shift; [ $# -gt 0 ] && shift
            ;;
        *)
            shift
            ;;
    esac
done

# 3. Trigger filter (only applies when VITL_TRIGGER is restrictive AND
#    a --trigger value was passed)
ALLOWED="$(echo "${VITL_TRIGGER:-all}" | tr '[:upper:]' '[:lower:]')"
if [ -n "$TRIGGER" ] && [ "$ALLOWED" != "all" ]; then
    if ! echo ",$ALLOWED," | grep -q ",$TRIGGER,"; then
        echo "[visual-in-the-loop] filtered out: trigger=$TRIGGER not in VITL_TRIGGER=$ALLOWED" >&2
        exit 0
    fi
fi

# 4. Generate one image (VITL_LANG carries the resolved diagram language)
IMG=$(VITL_LANG="$LANG_VALUE" node "$SCRIPT_DIR/generate.mjs")
GEN_STATUS=$?
if [ $GEN_STATUS -ne 0 ] || [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "[visual-in-the-loop] generation failed, continuing without visual" >&2
    exit 0
fi

# 5. Show it
bash "$SCRIPT_DIR/show.sh" "$IMG" || true
echo "[visual-in-the-loop] rendered: $IMG"
