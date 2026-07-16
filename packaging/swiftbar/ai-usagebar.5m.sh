#!/usr/bin/env bash
#
# <xbar.title>AI Usagebar</xbar.title>
# <xbar.version>v0.5.0</xbar.version>
# <xbar.author>ai-usagebar</xbar.author>
# <xbar.desc>AI plan usage (Anthropic / OpenAI / Z.AI / OpenRouter) in the menu bar.</xbar.desc>
# <xbar.dependencies>ai-usagebar,jq</xbar.dependencies>
# <xbar.abouturl>https://github.com/Zenardi/ai-usagebar</xbar.abouturl>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
#
# SwiftBar / xbar plugin for ai-usagebar — shows the active vendor's usage as a
# native macOS menu-bar item, with a click-dropdown for the full breakdown and
# actions (refresh, cycle vendor, open the TUI).
#
# Install:
#   brew install --cask swiftbar
#   brew install Zenardi/tap/ai-usagebar jq
#   cp ai-usagebar.5m.sh "<your SwiftBar plugin folder>/" && chmod +x "$_"
#   then refresh SwiftBar (menu → Refresh All)
#
# The ".5m." in the filename is SwiftBar's refresh interval (5 minutes). Rename
# to change it, e.g. ai-usagebar.10m.sh. Keep it ≥ ~2m: the Anthropic/OpenAI
# endpoints rate-limit aggressively below ~300s (the widget caches for 60s).

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

BIN="$(command -v ai-usagebar || echo /opt/homebrew/bin/ai-usagebar)"
TUI="$(command -v ai-usagebar-tui || echo /opt/homebrew/bin/ai-usagebar-tui)"
JQ="$(command -v jq || echo /opt/homebrew/bin/jq)"

FORMAT='{vendor_short} {session_pct}% · {session_reset}'

# One Dark severity palette (class → hex), matching the TUI / Waybar tooltip.
color_for() {
    case "$1" in
        critical) echo '#e06c75' ;;
        high)     echo '#d19a66' ;;
        mid)      echo '#e5c07b' ;;
        *)        echo '#98c379' ;;
    esac
}

json="$("$BIN" --json --plain --format "$FORMAT" 2>/dev/null || true)"
text="$(printf '%s' "$json" | "$JQ" -r '.text // "⚠"' 2>/dev/null || echo '⚠')"
tooltip="$(printf '%s' "$json" | "$JQ" -r '.tooltip // ""' 2>/dev/null || echo '')"
class="$(printf '%s' "$json" | "$JQ" -r '.class // "low"' 2>/dev/null || echo low)"
color="$(color_for "$class")"

# --- Menu-bar item ---
echo "${text} | sfimage=chart.bar color=${color}"
echo "---"

# --- Dropdown: the full per-window breakdown (same box as the Waybar tooltip,
#     rendered in a monospace font so it aligns). ---
if [ -n "$tooltip" ]; then
    printf '%s\n' "$tooltip" | while IFS= read -r line; do
        printf '%s | font=Menlo size=13\n' "$line"
    done
    echo "---"
fi

echo "Refresh | refresh=true sfimage=arrow.clockwise"
echo "Cycle next vendor | bash=\"$BIN\" param1=\"--cycle-next\" terminal=false refresh=true sfimage=arrow.right"
echo "Cycle previous vendor | bash=\"$BIN\" param1=\"--cycle-prev\" terminal=false refresh=true sfimage=arrow.left"
echo "Open full TUI | bash=\"$TUI\" terminal=true sfimage=terminal"
echo "---"
echo "ai-usagebar on GitHub | href=https://github.com/Zenardi/ai-usagebar sfimage=link"
