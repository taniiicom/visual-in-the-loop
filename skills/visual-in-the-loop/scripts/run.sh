#!/usr/bin/env bash
# Entry point: master switch -> trigger filter -> generate -> show.
#
# Env vars (all optional):
#   VITL_ENABLED   master switch. 0/false/no/off (case-insensitive) disables.
#                  Unset or anything else -> enabled.
#   VITL_TRIGGER   comma-separated allowed triggers (e.g. "plan,clarify") or
#                  "all". Default: all.
#
# Argv (optional):
#   --trigger <type>   one of plan / clarify / decision, passed by the agent.
#                      If omitted, the skill still fires (fail-safe).
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

# 2. Parse --trigger arg (optional)
TRIGGER=""
if [ "${1:-}" = "--trigger" ]; then
    TRIGGER="${2:-}"
    shift 2 || shift
fi

# 3. Trigger filter (only applies when VITL_TRIGGER is restrictive AND
#    a --trigger value was passed)
ALLOWED="$(echo "${VITL_TRIGGER:-all}" | tr '[:upper:]' '[:lower:]')"
if [ -n "$TRIGGER" ] && [ "$ALLOWED" != "all" ]; then
    if ! echo ",$ALLOWED," | grep -q ",$TRIGGER,"; then
        echo "[visual-in-the-loop] filtered out: trigger=$TRIGGER not in VITL_TRIGGER=$ALLOWED" >&2
        exit 0
    fi
fi

# 4. Generate one image
IMG=$(node "$SCRIPT_DIR/generate.mjs")
GEN_STATUS=$?
if [ $GEN_STATUS -ne 0 ] || [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "[visual-in-the-loop] generation failed, continuing without visual" >&2
    exit 0
fi

# 5. Show it
bash "$SCRIPT_DIR/show.sh" "$IMG" || true
echo "[visual-in-the-loop] rendered: $IMG"
