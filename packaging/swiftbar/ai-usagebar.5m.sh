#!/usr/bin/env bash
#
# <xbar.title>AI Usagebar</xbar.title>
# <xbar.version>v0.5.1</xbar.version>
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
# The dropdown is drawn as native macOS menu rows (SF Symbols + system colors),
# NOT the ASCII/Pango tooltip box the Waybar/Linux build uses. It pulls every
# value from ONE `ai-usagebar` call via a tab-packed --format string.
#
# Install:
#   brew install --cask swiftbar
#   brew install Zenardi/tap/ai-usagebar jq
#   cp ai-usagebar.5m.sh "<your SwiftBar plugin folder>/" && chmod +x "$_"
#   then refresh SwiftBar (menu → Refresh All)
#
# The ".5m." in the filename is SwiftBar's refresh interval (5 minutes). Rename
# to change it, e.g. ai-usagebar.10m.sh. Keep it >= ~2m: the Anthropic/OpenAI
# endpoints rate-limit aggressively below ~300s (the widget caches for 60s).

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

BIN="$(command -v ai-usagebar || echo /opt/homebrew/bin/ai-usagebar)"
TUI="$(command -v ai-usagebar-tui || echo /opt/homebrew/bin/ai-usagebar-tui)"
JQ="$(command -v jq || echo /usr/bin/jq)"

# TAB-packed format: one call yields every field the native dropdown needs.
# TAB is a safe delimiter — it never appears in a plan name, percentage, or
# reset string, and (unlike a multi-byte char) `read`/IFS split on it reliably.
# On a hard error the widget ignores --format and emits "⚠", which contains no
# TAB — so a missing delimiter is our error sentinel.
TAB=$'\t'
FORMAT="{vendor_short}${TAB}{plan}${TAB}{session_pct}${TAB}{session_reset}${TAB}{weekly_pct}${TAB}{weekly_reset}"

# Secondary (dimmed) label color — macOS menu secondaryLabelColor-ish gray.
# Reads correctly on both light and dark menus.
DIM='#8e8e93'

# One Dark severity palette (class -> hex), matching the TUI / Waybar tooltip.
color_for() {
    case "$1" in
        critical) echo '#e06c75' ;;
        high)     echo '#d19a66' ;;
        mid)      echo '#e5c07b' ;;
        *)        echo '#98c379' ;;
    esac
}

# Utilization percentage -> severity class. Same thresholds as the Rust
# `severity_for`: >=90 critical, >=75 high, >=50 mid, else low. Non-numeric
# (a vendor with no such window) falls back to low.
class_for_pct() {
    case "$1" in
        ''|*[!0-9]*) echo low; return ;;
    esac
    if   [ "$1" -ge 90 ]; then echo critical
    elif [ "$1" -ge 75 ]; then echo high
    elif [ "$1" -ge 50 ]; then echo mid
    else echo low
    fi
}

# Utilization percentage -> a gauge SF Symbol whose needle sits at the nearest
# available position, so the icon itself reads as a live usage meter.
gauge_for_pct() {
    case "$1" in
        ''|*[!0-9]*) echo 'gauge.with.dots.needle.0percent'; return ;;
    esac
    if   [ "$1" -ge 84 ]; then echo 'gauge.with.dots.needle.100percent'
    elif [ "$1" -ge 59 ]; then echo 'gauge.with.dots.needle.67percent'
    elif [ "$1" -ge 42 ]; then echo 'gauge.with.dots.needle.50percent'
    elif [ "$1" -ge 17 ]; then echo 'gauge.with.dots.needle.33percent'
    else echo 'gauge.with.dots.needle.0percent'
    fi
}

# Human vendor name + a brand-ish SF Symbol from the short code the widget
# prints, for the dropdown's header row.
vendor_name() {
    case "$1" in
        cld) echo 'Claude' ;;
        gpt) echo 'ChatGPT' ;;
        zai) echo 'Z.AI' ;;
        opr) echo 'OpenRouter' ;;
        *)   echo 'AI Usage' ;;
    esac
}
vendor_icon() {
    case "$1" in
        cld) echo 'sparkles' ;;
        gpt) echo 'bubble.left.and.bubble.right' ;;
        zai) echo 'bolt.fill' ;;
        opr) echo 'arrow.triangle.branch' ;;
        *)   echo 'cpu' ;;
    esac
}

# Emit the shared action block (refresh / cycle / TUI / GitHub).
actions() {
    echo "Refresh | refresh=true sfimage=arrow.clockwise"
    echo "Cycle next vendor | bash=\"$BIN\" param1=\"--cycle-next\" terminal=false refresh=true sfimage=chevron.right"
    echo "Cycle previous vendor | bash=\"$BIN\" param1=\"--cycle-prev\" terminal=false refresh=true sfimage=chevron.left"
    echo "Open full TUI | bash=\"$TUI\" terminal=true sfimage=terminal"
    echo "---"
    echo "ai-usagebar on GitHub | href=https://github.com/Zenardi/ai-usagebar sfimage=link"
}

json="$("$BIN" --json --plain --format "$FORMAT" 2>/dev/null || true)"
text="$(printf '%s' "$json" | "$JQ" -r '.text // ""' 2>/dev/null || echo '')"
tooltip="$(printf '%s' "$json" | "$JQ" -r '.tooltip // ""' 2>/dev/null || echo '')"
class="$(printf '%s' "$json" | "$JQ" -r '.class // "low"' 2>/dev/null || echo low)"

# --- Error path: no data / hard failure. `text` lacks the TAB delimiter. ---
case "$text" in
    *"$TAB"*) ;;
    *)
        echo "⚠ | sfimage=exclamationmark.triangle.fill color=$(color_for critical)"
        echo "---"
        if [ -n "$tooltip" ]; then
            printf '%s\n' "$tooltip" | while IFS= read -r line; do
                line="${line//|/¦}"
                case "$line" in --*) line=" $line" ;; esac
                [ -n "$line" ] && printf '%s | color=%s size=12\n' "$line" "$DIM"
            done
        else
            echo "No usage data | color=$DIM size=12"
            echo "Run \`claude\` or \`codex login\` once to authenticate. | color=$DIM size=12"
        fi
        echo "---"
        actions
        exit 0
        ;;
esac

# --- Healthy path: split the tab-packed fields. ---
IFS="$TAB" read -r vshort plan spct sreset wpct wreset <<EOF
$text
EOF

vname="$(vendor_name "$vshort")"
plan="${plan//|/¦}"
scolor="$(color_for "$(class_for_pct "$spct")")"
wcolor="$(color_for "$(class_for_pct "$wpct")")"

# --- Menu-bar item: compact "cld 21% · 3h 26m" + a live usage gauge. ---
echo "${vshort} ${spct}% · ${sreset} | sfimage=$(gauge_for_pct "$spct") color=$(color_for "$class")"
echo "---"

# --- Plan header (system default color = adapts to light/dark). ---
echo "${vname} ${plan} | sfimage=$(vendor_icon "$vshort")"
echo "---"

# --- Session window (5-hour rolling). Value colored by severity; reset dimmed. ---
echo "Session · ${spct}% | sfimage=hourglass color=${scolor}"
case "$sreset" in
    '—'|'') : ;;   # e.g. OpenRouter has no session-reset window
    *) echo "Resets in ${sreset} | sfimage=clock color=${DIM} size=12" ;;
esac

# --- Weekly window (7-day). ---
echo "Weekly · ${wpct}% | sfimage=calendar color=${wcolor}"
case "$wreset" in
    '—'|'') : ;;
    *) echo "Resets in ${wreset} | sfimage=clock color=${DIM} size=12" ;;
esac
echo "---"

actions
