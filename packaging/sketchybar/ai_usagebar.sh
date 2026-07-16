#!/usr/bin/env bash
#
# SketchyBar plugin for ai-usagebar — https://github.com/akitaonrails/ai-usagebar
#
# SketchyBar runs this on `update_freq`, on subscribed events (e.g.
# `aibar_refresh`), and on scroll (`mouse.scrolled`). It reads the widget's
# markup-free JSON ({text, tooltip, class}) and maps the severity class to a
# color. Requires `jq` (brew install jq).
#
# Env overrides:
#   AI_USAGEBAR_BIN     path to the ai-usagebar binary (default: from $PATH)
#   AI_USAGEBAR_FORMAT  bar-text format string (default below)
set -euo pipefail

BIN="${AI_USAGEBAR_BIN:-ai-usagebar}"

# Set the default format WITHOUT a brace-containing `${:-}` default, which would
# be truncated at the first `}` by the shell.
FORMAT="${AI_USAGEBAR_FORMAT:-}"
if [ -z "$FORMAT" ]; then
    FORMAT='{vendor_short} {session_pct}% · {session_reset}'
fi

# One Dark severity palette as SketchyBar 0xAARRGGBB colors.
COLOR_LOW=0xff98c379
COLOR_MID=0xffe5c07b
COLOR_HIGH=0xffd19a66
COLOR_CRITICAL=0xffe06c75

# Scroll-to-cycle: SketchyBar sends `mouse.scrolled` with $SCROLL_DELTA
# (positive = scroll up). The cycle nudges its own refresh via refresh_command.
if [ "${SENDER:-}" = "mouse.scrolled" ]; then
    if awk "BEGIN { exit !(${SCROLL_DELTA:-0} > 0) }" 2>/dev/null; then
        "$BIN" --cycle-next >/dev/null 2>&1 || true
    else
        "$BIN" --cycle-prev >/dev/null 2>&1 || true
    fi
fi

json="$("$BIN" --json --plain --format "$FORMAT" 2>/dev/null || true)"
label="$(printf '%s' "$json" | jq -r '.text // "…"' 2>/dev/null || echo '…')"
class="$(printf '%s' "$json" | jq -r '.class // "low"' 2>/dev/null || echo low)"

case "$class" in
    critical) color=$COLOR_CRITICAL ;;
    high)     color=$COLOR_HIGH ;;
    mid)      color=$COLOR_MID ;;
    *)        color=$COLOR_LOW ;;
esac

sketchybar --set "${NAME:-ai_usagebar}" label="$label" label.color="$color"
