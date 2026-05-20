#!/usr/bin/env bash
# Entry point: master switch → trigger filter → generate → show.
#
# Env vars (all optional):
#   VITL_ENABLED   master switch. Set to 0/false/no/off (case-insensitive) to disable.
#                  Unset or anything else → enabled.
#   VITL_TRIGGER   comma-separated allowed triggers (e.g. "plan,clarify") or "all".
#                  Default: all (always fire).
#
# Argv (optional):
#   --trigger <type>   one of plan / clarify / decision, passed by the agent.
#                      If omitted, the skill still fires (fail-safe).
#
# Stdin:
#   Either a JSON array of {title, content} objects (or plain strings) for
#   multi-slide mode, or plain text for single-image mode. See generate.mjs.

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

# 3. Trigger filter (only applies when both VITL_TRIGGER is restrictive AND --trigger was passed)
ALLOWED="$(echo "${VITL_TRIGGER:-all}" | tr '[:upper:]' '[:lower:]')"
if [ -n "$TRIGGER" ] && [ "$ALLOWED" != "all" ]; then
    if ! echo ",$ALLOWED," | grep -q ",$TRIGGER,"; then
        echo "[visual-in-the-loop] filtered out: trigger=$TRIGGER not in VITL_TRIGGER=$ALLOWED" >&2
        exit 0
    fi
fi

# 4. Generate (produces 1..N TSV lines: path<TAB>title)
OUTPUT=$(node "$SCRIPT_DIR/generate.mjs")
GEN_STATUS=$?
if [ $GEN_STATUS -ne 0 ] || [ -z "$OUTPUT" ]; then
    echo "[visual-in-the-loop] generation failed, continuing without visual" >&2
    exit 0
fi

# 5. Show (TSV via stdin)
echo "$OUTPUT" | bash "$SCRIPT_DIR/show.sh" || true

# 6. Summary line for the agent
COUNT=$(echo "$OUTPUT" | grep -c .)
echo "[visual-in-the-loop] rendered $COUNT image(s)"
