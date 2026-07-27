#!/usr/bin/env bash
#
# install-macos.sh — one-shot macOS setup for ai-usagebar's menu-bar item.
#
# Idempotent: safe to re-run. It
#   1. installs / refreshes the SwiftBar plugin,
#   2. points SwiftBar at its plugin folder,
#   3. creates an `ai-usagebar.app` launcher in /Applications (branded icon) so
#      Spotlight finds it by name (SwiftBar is a shared host and keeps its own),
#   4. registers SwiftBar as a login item so the menu-bar item auto-starts,
#   5. launches + refreshes SwiftBar.
#
# Prereqs (see the repo's macOS section):
#   brew install Zenardi/tap/ai-usagebar   # the widget + TUI
#   brew install --cask swiftbar           # the menu-bar host
#   brew install jq                        # used by the plugin
#
# Run from a clone (uses the local plugin + icon) or standalone (fetches them):
#   ./packaging/swiftbar/install-macos.sh
#   curl -fsSL https://raw.githubusercontent.com/Zenardi/ai-usagebar/main/packaging/swiftbar/install-macos.sh | bash

set -euo pipefail

SWIFTBAR_APP="/Applications/SwiftBar.app"
SWIFTBAR_BUNDLE_ID="com.ameba.SwiftBar"
PLUGIN_DIR="$HOME/Library/Application Support/SwiftBar"
PLUGIN_NAME="ai-usagebar.5m.sh"
ICON_NAME="ai-usagebar.icns"
LAUNCHER_APP="/Applications/ai-usagebar.app"
RAW_BASE="https://raw.githubusercontent.com/Zenardi/ai-usagebar/main/packaging/swiftbar"
VERSION="0.5.1"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }

# --- 0. sanity ---------------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  warn "This installer is macOS-only. On Linux use the Waybar module instead."
  exit 1
fi
if [[ ! -d "$SWIFTBAR_APP" ]]; then
  warn "SwiftBar not found at $SWIFTBAR_APP — install it first:"
  warn "    brew install --cask swiftbar"
  exit 1
fi
command -v jq >/dev/null 2>&1 || warn "jq not found — the plugin needs it: brew install jq"
command -v ai-usagebar >/dev/null 2>&1 || warn "ai-usagebar not on PATH — install it: brew install Zenardi/tap/ai-usagebar"

# --- 1. install / refresh the plugin ----------------------------------------
say "Installing the SwiftBar plugin → $PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ -f "$SELF_DIR/$PLUGIN_NAME" ]]; then
  cp "$SELF_DIR/$PLUGIN_NAME" "$PLUGIN_DIR/$PLUGIN_NAME"
else
  curl -fsSL "$RAW_BASE/$PLUGIN_NAME" -o "$PLUGIN_DIR/$PLUGIN_NAME"
fi
chmod +x "$PLUGIN_DIR/$PLUGIN_NAME"

# --- 2. point SwiftBar at the plugin folder ---------------------------------
defaults write "$SWIFTBAR_BUNDLE_ID" PluginDirectory "$PLUGIN_DIR"

# --- 3. Spotlight-branded launcher app --------------------------------------
# SwiftBar is a shared host, so we don't rename it. Instead we drop a tiny app
# named "ai-usagebar" (with its own gauge icon) that just launches + refreshes
# SwiftBar — so searching Spotlight for "ai-usagebar" finds a branded entry.
# Built locally (no quarantine → no Gatekeeper prompt) and survives upgrades.
say "Creating Spotlight launcher → $LAUNCHER_APP"
rm -rf "$LAUNCHER_APP"
mkdir -p "$LAUNCHER_APP/Contents/MacOS" "$LAUNCHER_APP/Contents/Resources"

cat > "$LAUNCHER_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>ai-usagebar</string>
    <key>CFBundleDisplayName</key>     <string>ai-usagebar</string>
    <key>CFBundleIdentifier</key>      <string>io.github.zenardi.ai-usagebar-launcher</string>
    <key>CFBundleExecutable</key>      <string>ai-usagebar</string>
    <key>CFBundleIconFile</key>        <string>ai-usagebar</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
    <key>CFBundleShortVersionString</key>    <string>${VERSION}</string>
    <key>CFBundleVersion</key>         <string>${VERSION}</string>
    <key>LSUIElement</key>             <true/>
    <key>LSMinimumSystemVersion</key>  <string>11.0</string>
    <key>NSHumanReadableCopyright</key><string>ai-usagebar — launches SwiftBar</string>
</dict>
</plist>
PLIST

cat > "$LAUNCHER_APP/Contents/MacOS/ai-usagebar" <<'LAUNCH'
#!/bin/sh
# ai-usagebar launcher: ensure SwiftBar is running, then refresh its plugins so
# the ai-usagebar menu-bar item shows current usage immediately.
open -b com.ameba.SwiftBar 2>/dev/null || open -a "SwiftBar" 2>/dev/null || true
open -g "swiftbar://refreshallplugins" 2>/dev/null || true
LAUNCH
chmod +x "$LAUNCHER_APP/Contents/MacOS/ai-usagebar"

# Branded icon (the gauge motif) so Finder/Spotlight/Dock don't show a generic app.
if [[ -f "$SELF_DIR/$ICON_NAME" ]]; then
  cp "$SELF_DIR/$ICON_NAME" "$LAUNCHER_APP/Contents/Resources/$ICON_NAME"
else
  curl -fsSL "$RAW_BASE/$ICON_NAME" -o "$LAUNCHER_APP/Contents/Resources/$ICON_NAME" \
    || warn "Could not fetch the icon; the launcher will use a generic icon."
fi

# Re-register with LaunchServices + nudge Spotlight so the new name/icon show now.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
[[ -x "$LSREGISTER" ]] && "$LSREGISTER" -f "$LAUNCHER_APP" >/dev/null 2>&1 || true
touch "$LAUNCHER_APP"
/usr/bin/mdimport "$LAUNCHER_APP" >/dev/null 2>&1 || true

# --- 4. autostart at login --------------------------------------------------
say "Registering SwiftBar as a login item (autostart)"
osascript <<'APPLESCRIPT' >/dev/null 2>&1 || warn "Could not register login item (grant Automation permission if prompted)."
tell application "System Events"
    if not (exists login item "SwiftBar") then
        make login item at end with properties ¬
            {path:"/Applications/SwiftBar.app", hidden:true}
    end if
end tell
APPLESCRIPT

# --- 5. launch + refresh ----------------------------------------------------
say "Launching SwiftBar"
open -b "$SWIFTBAR_BUNDLE_ID" 2>/dev/null || open -a "SwiftBar" 2>/dev/null || true
open -g "swiftbar://refreshallplugins" 2>/dev/null || true

cat <<DONE

Done. The ai-usagebar item is in your menu bar (top-right, by the clock).
  • Spotlight: search "ai-usagebar" — the branded launcher opens/refreshes it.
  • Autostart: SwiftBar is now in System Settings → General → Login Items.

Remove autostart:  osascript -e 'tell application "System Events" to delete login item "SwiftBar"'
Remove launcher:   rm -rf "$LAUNCHER_APP"
DONE
