# ai-usagebar

Waybar widget and tabbed TUI for AI plan usage across **Anthropic Claude**, **OpenAI Codex/ChatGPT**, **Z.AI (GLM)**, and **OpenRouter**.

This started as a Rust port of [`claudebar`](https://github.com/mryll/claudebar) and stays drop-in compatible with it. It keeps the minimalist Pango-bordered tooltip, Omarchy theme auto-detection, and flock-protected OAuth refresh, then adds three more vendors and a proper testable codebase instead of one long shell script.

**WAYLAND**

![Waybar widget showing `cld 29% · 1h 12m` in the top-right, with the hover tooltip showing Claude Max 20x session/weekly/sonnet/extra-usage progress bars](screenshot.png)


**GNOME (UBUNTU)**

![GNOME widget showing `cld 29% · 1h 12m` in the top-right, with the click-to-open native popup showing Claude Max 20x session/weekly/sonnet/extra-usage progress bars](screenshot_gnome.png)

## Features

- **Per-vendor Waybar modules** with the same JSON shape as claudebar.
- **Tabbed TUI** (`ai-usagebar-tui`) with Tab/h/l switching, per-tab refresh, and 60-second auto-refresh. Native ratatui widgets fill the available terminal width and keep the vendor tabs visually consistent.
- **Scroll-to-cycle on the bar**: wire `on-scroll-up` / `on-scroll-down`, and one bar item cycles through your enabled vendors.
- **Config-driven primary vendor**: set `[ui] primary` once; the widget shows that vendor by default and the TUI opens on its tab.
- **Local testing tools**: `--pretty` renders ANSI-colored terminal output (auto-detects TTY), and `--watch N` re-renders every N seconds.
- **Drop-in claudebar compatibility** with the same flags (`--icon`, `--format`, `--tooltip-format`, `--pace-tolerance`, `--format-pace-color`, `--tooltip-pace-pts`, `--color-*`) and `{placeholders}`.
- **Always exits 0**, because Waybar hides modules that don't.
- **Atomic cache writes + flock**, so multi-monitor Waybar instances can coexist without API stampedes.
- **Separate transient and hard errors**: DNS/timeout failures show a quiet `Loading…`; HTTP 4xx/5xx errors put the code in the tooltip.
- **Live API smoke tests**: `make smoke` hits the real undocumented endpoints and catches schema drift early.

## Install

### Arch (AUR)

Two packages. Pick one:

```bash
yay -S ai-usagebar-bin    # prebuilt binary from GitHub Releases (fast, ~5s install)
yay -S ai-usagebar        # compiles from source (~30-60s, hermetic)
```

The `-bin` variant downloads the same x86_64 ELF that CI built and tested. The source variant compiles locally with your toolchain. Both install identical binaries to `/usr/bin/`. If you already have one installed, switch with `yay -S` the other package; pacman handles the swap through `conflicts`/`provides`.

### macOS (Homebrew)

```bash
brew install akitaonrails/tap/ai-usagebar
```

Installs the same universal-tested binaries CI built (Apple Silicon + Intel). See the [macOS (SketchyBar)](#macos-sketchybar) section for bar setup, or just run `ai-usagebar-tui`.

### From source

```bash
cargo build --release
sudo make install                  # → /usr/local/bin
# or
make install PREFIX=$HOME/.local   # → ~/.local/bin
```

## Authentication

Each vendor authenticates a little differently. Anthropic and OpenAI use OAuth credentials that their official CLIs already wrote to disk, so **no env vars are needed.** Z.AI and OpenRouter use API keys. You can pass those through env vars or, if you don't source secrets in your shell, put them inline in `config.toml`.

| Vendor | Method | Action required |
|---|---|---|
| Anthropic | OAuth, read from `~/.claude/.credentials.json` | Run `claude` once to log in. Token auto-refreshes. |
| OpenAI | OAuth, read from `~/.codex/auth.json` | Run `codex login` once. Token auto-refreshes. |
| Z.AI | API key (`ZAI_API_KEY` env or `[zai] api_key` in config) | Set either. |
| OpenRouter | API key (`OPENROUTER_API_KEY` env or `[openrouter] api_key` in config) | Set either. |

### Credential resolution order (for API-key vendors)

For each API-key vendor, ai-usagebar checks in this order:

1. **Env var named by `api_key_env`** in config (defaults: `ZAI_API_KEY`, `OPENROUTER_API_KEY`). If set + non-empty, used.
2. **Inline `api_key`** in the same config section.
3. Otherwise, **error** with a message naming both options.

### Security

- If you put inline `api_key` values in config, `chmod 600 ~/.config/ai-usagebar/config.toml`. The default behavior reads only env vars, which is safer when your config might be world-readable.
- Don't commit your config dir if you check it into dotfiles unless you've redacted `api_key` lines.
- OAuth credential files (`~/.claude/.credentials.json`, `~/.codex/auth.json`) are managed by their respective CLIs and already chmod-protected.

## Configuration

`~/.config/ai-usagebar/config.toml` (optional — defaults enable all four vendors). Full example:

```toml
[ui]
# Which vendor the widget shows when --vendor is omitted, AND which tab
# is selected when the TUI opens. Defaults to anthropic when not set.
# primary = "anthropic"   # anthropic | openai | zai | openrouter

[anthropic]
enabled = true
# credentials_path = "/home/you/.claude/.credentials.json"

[openai]
enabled = true
# codex_auth_path = "/home/you/.codex/auth.json"

[zai]
enabled = true
api_key_env = "ZAI_API_KEY"
# api_key = "..."          # used if ZAI_API_KEY is unset; chmod 600 the file!
# plan_tier = "lite"       # lite | pro | max — display-only

[openrouter]
enabled = true
api_key_env = "OPENROUTER_API_KEY"
# api_key = "sk-or-v1-..."
```

## Quick start

```bash
# Local testing — auto-detects TTY and renders human-readable output.
ai-usagebar                        # uses [ui] primary (defaults to anthropic)
ai-usagebar --vendor openai
ai-usagebar --vendor zai
ai-usagebar --vendor openrouter

# Force Waybar JSON (e.g. piping into jq).
ai-usagebar --json

# Live preview while iterating on --format / --tooltip-format.
ai-usagebar --vendor openrouter --watch 5

# Interactive TUI with tabs.
ai-usagebar-tui
```

## Standalone TUI — no Waybar required

The two binaries are independent. If you don't run Waybar (or just want to check usage occasionally rather than have it on your bar permanently), `ai-usagebar-tui` works as a fully standalone terminal app:

```bash
ai-usagebar-tui                    # opens in your current terminal
```

It runs in any terminal emulator (Kitty, Alacritty, Foot, Ghostty, etc.), works in plain SSH sessions, and doesn't need a compositor or window manager integration. All controls and the Settings overlay work the same way. Use it as:

- An ad-hoc check ("am I close to my Claude weekly limit before I start a long session?")
- A foreground monitor on a secondary screen or tmux pane while you code
- A shell-only tool on remote machines (just install the binary; no Waybar/Hyprland dependencies)

The Waybar widget is optional. The TUI is the best way to see all four vendors at once, even if you never set up the widget.

## Waybar config

### Single module, scroll-to-cycle (recommended)

Use one bar item and scroll through your vendors. The TUI on-click still shows them all:

```jsonc
"modules-right": ["custom/aibar", ...],

"custom/aibar": {
    "exec": "ai-usagebar --format '{vendor_short} {session_pct}% · {session_reset}'",
    "return-type": "json",
    "interval": 300,
    "signal": 13,
    "tooltip": true,
    "on-click": "ai-usagebar-tui",
    "on-scroll-up":   "ai-usagebar --cycle-next",
    "on-scroll-down": "ai-usagebar --cycle-prev"
}
```

The `{vendor_short}` placeholder always expands to a 3-letter vendor ID (`cld` / `gpt` / `zai` / `opr`), so the bar text tells you which vendor is active. The other usage placeholders (`{session_pct}` for Anthropic, `{oai_session_pct}` for OpenAI, etc.) are vendor-specific. If you want one format string for all four cycled vendors, prefer the generic placeholders where available. For now, `{session_pct}` works for Anthropic only; the other vendors expose their own `{oai_*}` / `{zai_*}` / `{or_*}` families, which expand to empty strings for vendors that don't define them.

`signal: 13` lets the scroll-cycle commands refresh the bar instantly (via `SIGRTMIN+13`) instead of waiting for the next 300s interval.

### Per-vendor modules

If you'd rather see them all at once:

```jsonc
"modules-right": ["custom/claude", "custom/openai", "custom/openrouter", "custom/zai"],

"custom/claude": {
    "exec": "ai-usagebar --vendor anthropic --icon '󰚩'",
    "return-type": "json",
    "interval": 300,
    "tooltip": true,
    "on-click": "ai-usagebar-tui"
},
"custom/openai": {
    "exec": "ai-usagebar --vendor openai --icon '󱢆'",
    "return-type": "json",
    "interval": 300,
    "tooltip": true
},
"custom/openrouter": {
    "exec": "ai-usagebar --vendor openrouter --icon '󱙺' --format '{or_balance} · {or_used_today}'",
    "return-type": "json",
    "interval": 600,
    "tooltip": true
},
"custom/zai": {
    "exec": "ai-usagebar --vendor zai --icon '󰚩'",
    "return-type": "json",
    "interval": 300,
    "tooltip": true
}
```

> Why 300s? The Anthropic and OpenAI Codex endpoints are undocumented and rate-limit aggressively below ~300s. The cache TTL is 60s so multi-monitor instances coexist, but Waybar's polling interval should stay at 300s.

## Hyprland: float the TUI window

By default Hyprland tiles the TUI. To make `ai-usagebar-tui` open as a centered floating window, the same way Omarchy floats its own settings TUIs (Wi-Fi/`impala`, audio/`wiremix`, Bluetooth/`bluetui`), add this to `~/.config/hypr/hyprland.conf` or any sourced `.conf`, such as `looknfeel.conf`:

```ini
# ai-usagebar TUI — float + center + fixed size. omarchy-launch-tui sets the
# app-id from the binary basename, so the class is org.omarchy.ai-usagebar-tui.
# 875x600 matches the size Omarchy gives its own `floating-window`-tagged TUIs.
windowrule = float on, match:class ^(org\.omarchy\.ai-usagebar-tui)$
windowrule = center on, match:class ^(org\.omarchy\.ai-usagebar-tui)$
windowrule = size 875 600, match:class ^(org\.omarchy\.ai-usagebar-tui)$
```

Then `hyprctl reload` (no logout needed).

> Omarchy tags a hardcoded list of TUI app-ids with `floating-window` in `~/.local/share/omarchy/default/hypr/apps/system.conf`, which then applies `float + center + size 875 600`. The rules above set those values directly, so the size is deterministic regardless of which config is sourced first. If you launch the TUI differently (e.g. `kitty -e ai-usagebar-tui`), replace the class regex with whatever `hyprctl clients` reports for your terminal.

> Hyprland 0.46+ uses the unified `windowrule` keyword with `match:…` filters. The older `windowrulev2 = …, class:…` syntax still works on legacy Hyprland but is deprecated — use the form above on current Omarchy / Hyprland releases.

## GNOME (Ubuntu, Fedora, …)

GNOME Shell's top bar can't render Waybar-style hover tooltips with Pango markup, so this section provides a small custom Shell extension that shows the colored bar text in the panel and opens a **native popup** with progress-bar widgets when clicked. The popup is built from real St widgets (not Pango ASCII art), so the layout stays clean across fonts, sizes, and GNOME versions. As an alternative, you can skip the extension entirely and bind a keyboard shortcut to spawn the TUI in a floating terminal.

### Custom GNOME Shell extension

Tested on GNOME 45–50 (Ubuntu 24.04 / 24.10 / 25.04 / 26.04).

Drop the three files below into `~/.local/share/gnome-shell/extensions/ai-usagebar@local/`, log out and log back in (Wayland can't reload Shell extensions live), then enable it:

```bash
mkdir -p ~/.local/share/gnome-shell/extensions/ai-usagebar@local
# … write the three files below into the extension dir …

# Log out and back in (Wayland requirement), then:
gnome-extensions enable ai-usagebar@local
```

After install, click the new top-bar item to open the popup. It shows:

- A bold, colored **title** with the active plan (e.g. `Max 5x`, `ChatGPT Plus`, `GLM Coding Lite`, `OpenRouter`).
- Per-window rows with a **progress bar widget**, the percentage colored by severity (green / yellow / orange / red), and a `Resets in …` sub-line where applicable.
- An **`Updated HH:MM`** footer in your local timezone (uses `GLib.DateTime.new_now_local()` so it honors `/etc/localtime` instead of GJS's UTC `Date`).
- Clickable menu items to refresh, cycle the active vendor (`cld` → `gpt` → `zai` → `opr`), or open the full TUI.

The popup layout adapts per vendor — Session/Weekly/Sonnet/Extra-usage for Anthropic, Codex 5h/weekly + Credits for OpenAI, Session/Weekly/MCP for Z.AI, and Balance/Today/Week/Month for OpenRouter.

<details>
<summary><strong>metadata.json</strong></summary>

```json
{
  "uuid": "ai-usagebar@local",
  "name": "AI Usagebar",
  "description": "Top-bar indicator showing ai-usagebar plan usage. Click for a native popup with per-window progress bars across Anthropic / OpenAI / Z.AI / OpenRouter.",
  "shell-version": ["45", "46", "47", "48", "49", "50"],
  "url": "https://github.com/akitaonrails/ai-usagebar"
}
```

</details>

<details>
<summary><strong>extension.js</strong></summary>

```js
// AI Usagebar GNOME Shell extension.
// Top-bar indicator with a native widget popup showing per-window usage
// for the active vendor (Anthropic / OpenAI / Z.AI / OpenRouter).

import GObject from 'gi://GObject';
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const HOME = GLib.get_home_dir();
const AI_USAGEBAR =
    GLib.find_program_in_path('ai-usagebar') ?? `${HOME}/.local/bin/ai-usagebar`;
const AI_USAGEBAR_TUI =
    GLib.find_program_in_path('ai-usagebar-tui') ?? `${HOME}/.local/bin/ai-usagebar-tui`;

const TUI_SPAWN_ARGV = [
    GLib.find_program_in_path('ptyxis')
        ?? GLib.find_program_in_path('kgx')
        ?? GLib.find_program_in_path('gnome-terminal')
        ?? '/usr/bin/xterm',
    '--new-window', '-T', 'AI Usage', '--', AI_USAGEBAR_TUI,
];

const BAR_FORMAT = '{vendor_short} {session_pct}% · {session_reset}';
// Combined structured data — empty fields are normal for non-active vendors.
const POPUP_FORMAT = [
    '{vendor_short}', '{plan}',
    // Anthropic
    '{session_pct}', '{session_reset}', '{session_pace_indicator}',
    '{weekly_pct}', '{weekly_reset}', '{weekly_pace_indicator}',
    '{sonnet_pct}', '{sonnet_reset}',
    '{extra_spent}', '{extra_limit}', '{extra_pct}',
    // OpenAI
    '{oai_plan}', '{oai_session_pct}', '{oai_session_reset}',
    '{oai_weekly_pct}', '{oai_weekly_reset}',
    '{oai_code_review_pct}', '{oai_credit_balance}',
    // Z.AI
    '{zai_plan}', '{zai_session_pct}', '{zai_session_reset}',
    '{zai_weekly_pct}', '{zai_weekly_reset}',
    '{zai_mcp_pct}', '{zai_mcp_reset}',
    // OpenRouter
    '{or_label}', '{or_balance}', '{or_total}',
    '{or_used_today}', '{or_used_week}', '{or_used_month}',
].join('|');

const REFRESH_SECONDS = 300;

// One Dark palette — matches ai-usagebar's TUI/Waybar tooltip colors.
const COLOR_LOW = '#98c379';
const COLOR_MID = '#e5c07b';
const COLOR_HIGH = '#d19a66';
const COLOR_CRITICAL = '#e06c75';
const COLOR_TITLE = '#61afef';

function colorForPct(pct) {
    if (pct < 50) return COLOR_LOW;
    if (pct < 80) return COLOR_MID;
    if (pct < 95) return COLOR_HIGH;
    return COLOR_CRITICAL;
}

const BAR_PX = 280;
const BAR_HEIGHT = 8;

function makeRow() {
    const item = new PopupMenu.PopupBaseMenuItem({ reactive: false, can_focus: false });
    item.add_style_class_name('ai-usagebar-row');

    const col = new St.BoxLayout({
        vertical: true,
        x_expand: true,
        style_class: 'ai-usagebar-row-col',
    });

    const header = new St.BoxLayout({ x_expand: true });
    const nameLabel = new St.Label({
        x_expand: true,
        y_align: Clutter.ActorAlign.CENTER,
        style_class: 'ai-usagebar-row-name',
    });
    const pctLabel = new St.Label({
        x_expand: false,
        y_align: Clutter.ActorAlign.CENTER,
        style_class: 'ai-usagebar-row-pct',
    });
    header.add_child(nameLabel);
    header.add_child(pctLabel);
    col.add_child(header);

    // Progress bar container — explicit Clutter sizing + CSS min-* for safety.
    const barContainer = new St.BoxLayout({
        x_expand: false,
        x_align: Clutter.ActorAlign.START,
        style_class: 'ai-usagebar-bar-container',
    });
    barContainer.set_size(BAR_PX, BAR_HEIGHT);
    const filled = new St.Widget({
        style_class: 'ai-usagebar-bar-filled',
    });
    filled.set_height(BAR_HEIGHT);
    barContainer.add_child(filled);
    col.add_child(barContainer);

    const subLabel = new St.Label({
        style_class: 'ai-usagebar-row-sub',
    });
    col.add_child(subLabel);

    item.add_child(col);
    return { item, nameLabel, pctLabel, filled, barContainer, subLabel };
}

function updateRowPct(row, { name, pct, sub, pace }) {
    row.item.visible = true;
    row.nameLabel.set_text(name);

    const safePct = Number.isFinite(pct) ? pct : 0;
    const color = colorForPct(safePct);
    const pctText = pace ? `${safePct}% ${pace}` : `${safePct}%`;
    row.pctLabel.set_text(pctText);
    row.pctLabel.set_style(`color: ${color};`);

    const filledPx = Math.round((Math.max(0, Math.min(100, safePct)) / 100) * BAR_PX);
    row.filled.set_width(filledPx);
    row.filled.set_style(`background-color: ${color}; border-radius: 3px;`);
    row.barContainer.visible = true;

    if (sub) {
        row.subLabel.set_text(sub);
        row.subLabel.visible = true;
    } else {
        row.subLabel.visible = false;
    }
}

function updateRowValue(row, { name, value, color }) {
    // For non-percentage rows (credits, balance, dollar amounts).
    row.item.visible = true;
    row.nameLabel.set_text(name);
    row.pctLabel.set_text(value);
    row.pctLabel.set_style(`color: ${color || COLOR_TITLE};`);
    row.barContainer.visible = false;
    row.subLabel.visible = false;
}

function parseIntOrNull(s) {
    const n = parseInt(s, 10);
    return Number.isFinite(n) ? n : null;
}

const Indicator = GObject.registerClass(
class Indicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'AI Usagebar');

        this._label = new St.Label({
            text: 'ai-usagebar…',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._label.clutter_text.set_use_markup(true);
        this.add_child(this._label);

        // Title (plan name) — bold, centered, colored.
        this._titleLabel = new St.Label({
            text: 'Loading…',
            x_align: Clutter.ActorAlign.CENTER,
            x_expand: true,
        });
        this._titleLabel.add_style_class_name('ai-usagebar-title');
        const titleItem = new PopupMenu.PopupBaseMenuItem({ reactive: false, can_focus: false });
        titleItem.add_style_class_name('ai-usagebar-title-item');
        titleItem.add_child(this._titleLabel);
        this.menu.addMenuItem(titleItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Four data rows — visibility and content updated per vendor.
        this._rows = [makeRow(), makeRow(), makeRow(), makeRow()];
        for (const r of this._rows) this.menu.addMenuItem(r.item);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Footer — last-updated time.
        this._footerLabel = new St.Label({
            text: '',
            x_align: Clutter.ActorAlign.CENTER,
            x_expand: true,
        });
        this._footerLabel.add_style_class_name('ai-usagebar-footer');
        const footerItem = new PopupMenu.PopupBaseMenuItem({ reactive: false, can_focus: false });
        footerItem.add_child(this._footerLabel);
        this.menu.addMenuItem(footerItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        const refresh = new PopupMenu.PopupMenuItem('Refresh now');
        refresh.connect('activate', () => this._refresh());
        this.menu.addMenuItem(refresh);

        const cycleNext = new PopupMenu.PopupMenuItem('Cycle next vendor');
        cycleNext.connect('activate', () => this._spawn([AI_USAGEBAR, '--cycle-next']));
        this.menu.addMenuItem(cycleNext);

        const cyclePrev = new PopupMenu.PopupMenuItem('Cycle previous vendor');
        cyclePrev.connect('activate', () => this._spawn([AI_USAGEBAR, '--cycle-prev']));
        this.menu.addMenuItem(cyclePrev);

        const tuiItem = new PopupMenu.PopupMenuItem('Open full TUI');
        tuiItem.connect('activate', () => this._spawn(TUI_SPAWN_ARGV));
        this.menu.addMenuItem(tuiItem);

        this._refresh();
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, REFRESH_SECONDS, () => {
            this._refresh();
            return GLib.SOURCE_CONTINUE;
        });

        this.menu.connect('open-state-changed', (_menu, isOpen) => {
            if (isOpen) this._refresh();
        });
    }

    _spawn(argv) {
        try {
            Gio.Subprocess.new(argv, Gio.SubprocessFlags.NONE);
        } catch (e) {
            console.error(`ai-usagebar: spawn failed: ${e.message}`);
        }
    }

    _refresh() {
        this._runProc([AI_USAGEBAR, '--format', BAR_FORMAT], (data) => {
            if (data.text) this._label.clutter_text.set_markup(data.text);
        });
        this._runProc([AI_USAGEBAR, '--format', POPUP_FORMAT], (data) => {
            const plain = (data.text || '').replace(/<[^>]*>/g, '');
            this._renderPopup(plain.split('|'));
        });
    }

    _runProc(argv, onData) {
        let proc;
        try {
            proc = Gio.Subprocess.new(argv,
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE);
        } catch (e) {
            console.error(`ai-usagebar: spawn failed: ${e.message}`);
            return;
        }
        proc.communicate_utf8_async(null, null, (p, res) => {
            try {
                const [, out] = p.communicate_utf8_finish(res);
                const data = JSON.parse(out);
                onData(data);
            } catch (e) {
                console.error(`ai-usagebar: parse failed: ${e.message}`);
            }
        });
    }

    _renderPopup(fields) {
        // Field order MUST match POPUP_FORMAT above.
        const [
            vendorShort, plan,
            sessionPct, sessionReset, sessionPace,
            weeklyPct, weeklyReset, weeklyPace,
            sonnetPct, sonnetReset,
            extraSpent, extraLimit, extraPct,
            oaiPlan, oaiSessionPct, oaiSessionReset,
            oaiWeeklyPct, oaiWeeklyReset,
            oaiCodeReviewPct, oaiCreditBalance,
            zaiPlan, zaiSessionPct, zaiSessionReset,
            zaiWeeklyPct, zaiWeeklyReset,
            zaiMcpPct, zaiMcpReset,
            orLabel, orBalance, orTotal,
            orUsedToday, orUsedWeek, orUsedMonth,
        ] = fields;

        for (const r of this._rows) r.item.visible = false;

        // GLib.DateTime honors /etc/localtime — JS Date in GJS returns UTC.
        const now = GLib.DateTime.new_now_local();
        this._footerLabel.set_text(now.format('Updated %H:%M'));
        this._titleLabel.set_style(`color: ${COLOR_TITLE};`);

        if (vendorShort === 'cld') {
            this._titleLabel.set_text(plan || 'Claude');
            updateRowPct(this._rows[0], {
                name: 'Session',
                pct: parseIntOrNull(sessionPct) ?? 0,
                pace: sessionPace,
                sub: sessionReset ? `Resets in ${sessionReset}` : '',
            });
            updateRowPct(this._rows[1], {
                name: 'Weekly',
                pct: parseIntOrNull(weeklyPct) ?? 0,
                pace: weeklyPace,
                sub: weeklyReset ? `Resets in ${weeklyReset}` : '',
            });
            if (parseIntOrNull(sonnetPct) !== null) {
                updateRowPct(this._rows[2], {
                    name: 'Sonnet only',
                    pct: parseIntOrNull(sonnetPct),
                    pace: '',
                    sub: sonnetReset ? `Resets in ${sonnetReset}` : '',
                });
            }
            if (extraLimit && extraLimit !== '' && extraLimit !== '$0.00') {
                updateRowPct(this._rows[3], {
                    name: `Extra usage  ${extraSpent}`,
                    pct: parseIntOrNull(extraPct) ?? 0,
                    pace: '',
                    sub: `Limit ${extraLimit}`,
                });
            }
        } else if (vendorShort === 'gpt') {
            this._titleLabel.set_text(oaiPlan || 'ChatGPT');
            updateRowPct(this._rows[0], {
                name: 'Codex 5h',
                pct: parseIntOrNull(oaiSessionPct) ?? 0,
                pace: '',
                sub: oaiSessionReset ? `Resets in ${oaiSessionReset}` : '',
            });
            updateRowPct(this._rows[1], {
                name: 'Codex weekly',
                pct: parseIntOrNull(oaiWeeklyPct) ?? 0,
                pace: '',
                sub: oaiWeeklyReset ? `Resets in ${oaiWeeklyReset}` : '',
            });
            if (parseIntOrNull(oaiCodeReviewPct) !== null) {
                updateRowPct(this._rows[2], {
                    name: 'Code review weekly',
                    pct: parseIntOrNull(oaiCodeReviewPct),
                    pace: '',
                    sub: '',
                });
            }
            if (oaiCreditBalance) {
                updateRowValue(this._rows[3], {
                    name: 'Credits',
                    value: oaiCreditBalance,
                    color: COLOR_LOW,
                });
            }
        } else if (vendorShort === 'zai') {
            this._titleLabel.set_text(zaiPlan || 'GLM');
            updateRowPct(this._rows[0], {
                name: 'Session',
                pct: parseIntOrNull(zaiSessionPct) ?? 0,
                pace: '',
                sub: zaiSessionReset ? `Resets in ${zaiSessionReset}` : '',
            });
            updateRowPct(this._rows[1], {
                name: 'Weekly',
                pct: parseIntOrNull(zaiWeeklyPct) ?? 0,
                pace: '',
                sub: zaiWeeklyReset ? `Resets in ${zaiWeeklyReset}` : '',
            });
            if (parseIntOrNull(zaiMcpPct) !== null) {
                updateRowPct(this._rows[2], {
                    name: 'MCP tools',
                    pct: parseIntOrNull(zaiMcpPct),
                    pace: '',
                    sub: zaiMcpReset ? `Resets in ${zaiMcpReset}` : '',
                });
            }
        } else if (vendorShort === 'opr') {
            this._titleLabel.set_text(orLabel || 'OpenRouter');
            updateRowValue(this._rows[0], {
                name: 'Balance',
                value: orTotal ? `${orBalance} / ${orTotal}` : (orBalance || '—'),
                color: COLOR_LOW,
            });
            const usage = [
                ['Today', orUsedToday],
                ['This week', orUsedWeek],
                ['This month', orUsedMonth],
            ];
            for (let i = 0; i < usage.length; i++) {
                if (usage[i][1]) {
                    updateRowValue(this._rows[i + 1], {
                        name: usage[i][0],
                        value: usage[i][1],
                        color: COLOR_TITLE,
                    });
                }
            }
        } else {
            this._titleLabel.set_text('AI Usagebar');
            this._footerLabel.set_text('No active vendor data');
        }
    }

    destroy() {
        if (this._timer) {
            GLib.source_remove(this._timer);
            this._timer = null;
        }
        super.destroy();
    }
});

export default class AIUsagebarExtension extends Extension {
    enable() {
        this._indicator = new Indicator();
        Main.panel.addToStatusArea(this.uuid, this._indicator);
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
```

</details>

<details>
<summary><strong>stylesheet.css</strong></summary>

```css
/* Title (plan name) — bold, centered. */
.ai-usagebar-title-item {
    padding: 10px 14px 6px 14px;
}

.ai-usagebar-title {
    font-weight: bold;
    font-size: 11pt;
}

/* Per-window row. Generous vertical padding so rows don't squash. */
.ai-usagebar-row {
    padding: 8px 14px;
}

/* Vertical column inside each row: name+pct, then bar, then sub. */
.ai-usagebar-row-col {
    spacing: 4px;
}

.ai-usagebar-row-name {
    font-size: 10pt;
    color: #abb2bf;
}

.ai-usagebar-row-pct {
    font-weight: bold;
    font-size: 10pt;
    padding-left: 8px;
}

/* Bar dimensions are enforced in JS via set_size()/set_width() too,
   but we set min-* here as belt-and-braces. */
.ai-usagebar-bar-container {
    background-color: rgba(255, 255, 255, 0.10);
    border-radius: 3px;
    min-height: 8px;
    min-width: 280px;
}

.ai-usagebar-bar-filled {
    border-radius: 3px;
    min-height: 8px;
}

.ai-usagebar-row-sub {
    font-size: 9pt;
    color: rgba(220, 220, 220, 0.55);
    padding-top: 2px;
}

.ai-usagebar-footer {
    font-size: 9pt;
    color: rgba(220, 220, 220, 0.55);
    padding: 4px 14px 8px 14px;
}
```

</details>

After editing `extension.js` later (to change the format, refresh interval, terminal, or per-vendor layout), try the quick reload:

```bash
gnome-extensions disable ai-usagebar@local && gnome-extensions enable ai-usagebar@local
```

On Wayland, GNOME Shell sometimes keeps the previous JS module cached even after disable/enable — if your changes don't appear, **log out and back in**, which always reloads cleanly.

### Alternative: hotkey to TUI popup

Skip the extension entirely and bind a keyboard shortcut like `Super+U` to spawn `ai-usagebar-tui` in a floating terminal. No bar indicator, but the TUI shows all four vendors at once with live progress bars:

```bash
KEY=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['${KEY}']"
gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${KEY}" name 'AI Usage TUI'
gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${KEY}" command 'ptyxis --new-window -T "AI Usage" -- ai-usagebar-tui'
gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${KEY}" binding '<Super>u'
```

Swap `ptyxis` for `gnome-terminal`, `kgx`, `kitty`, `foot`, etc. as needed.

## macOS (SketchyBar)

macOS has no Waybar. The closest analog is [SketchyBar](https://github.com/FelixKratz/SketchyBar) (the config-driven bar people pair with yabai/aerospace), and ai-usagebar drives it through a small plugin. Everything works the same way underneath — the same binaries, the same undocumented endpoints, the same cache. If you don't want a bar at all, skip straight to the standalone TUI below.

Authentication is identical to Linux: the `claude` and `codex` CLIs write their OAuth credentials to `~/.claude/.credentials.json` and `~/.codex/auth.json` on macOS too, so **no env vars are needed** for Anthropic/OpenAI. Z.AI and OpenRouter still use API keys (env var or inline in config).

> **Paths on macOS.** ai-usagebar uses XDG-style dotfile paths on macOS just like Linux: config at `~/.config/ai-usagebar/config.toml` and cache under `~/.cache/ai-usagebar/`, not `~/Library/…`. This keeps it consistent with the `~/.claude` / `~/.codex` convention.

### Install

```bash
brew install akitaonrails/tap/ai-usagebar   # prebuilt binaries (Apple Silicon + Intel)
brew install sketchybar jq                   # sketchybar for the bar, jq for the plugin
```

Or build from source — the crate is pure Rust with a rustls/ring TLS stack (no OpenSSL, no system deps):

```bash
git clone https://github.com/akitaonrails/ai-usagebar && cd ai-usagebar
cargo build --release
make install PREFIX=$HOME/.local     # → ~/.local/bin (Apple Silicon Homebrew is /opt/homebrew)
```

### The `--plain` output mode

SketchyBar (and xbar/SwiftBar) can't render Waybar's Pango markup. Pass `--plain` and ai-usagebar strips all markup from the `text`/`tooltip` fields, so `--json --plain` yields clean strings you can parse with `jq`. It composes with any `--format` (even ones containing `{session_bar}`):

```bash
ai-usagebar --vendor anthropic --json --plain --format '{vendor_short} {session_pct}% · {session_reset}'
# {"text":"cld 29% · 1h 12m","tooltip":"…plain text…","class":"mid"}
```

### SketchyBar module

The plugin and an example item config live in [`packaging/sketchybar/`](packaging/sketchybar/). It reads the plain JSON, maps the severity `class` (low/mid/high/critical) to a color, handles scroll-to-cycle, and opens the TUI on click.

```bash
mkdir -p ~/.config/sketchybar/plugins
cp packaging/sketchybar/ai_usagebar.sh ~/.config/sketchybar/plugins/
chmod +x ~/.config/sketchybar/plugins/ai_usagebar.sh
# then merge packaging/sketchybar/sketchybarrc.example into your sketchybarrc
sketchybar --reload
```

For instant refresh after cycling vendors or saving settings, set a `refresh_command` in `~/.config/ai-usagebar/config.toml` — the macOS analog of Waybar's `signal: 13`:

```toml
[ui]
refresh_command = "sketchybar --trigger aibar_refresh"
```

The example `sketchybarrc` registers the `aibar_refresh` custom event, sets `update_freq=300`, subscribes to `mouse.scrolled` (scroll to cycle vendors), and opens `ai-usagebar-tui` on click. Swap the terminal in the plugin's `click_script` (`open -na Ghostty …`) for iTerm, kitty, etc.

### Alternative: just the TUI

The Waybar/SketchyBar widget is optional. `ai-usagebar-tui` is a fully standalone cross-platform terminal app — it runs in Terminal.app, iTerm2, Ghostty, Kitty, etc. with no bar setup at all, and shows all four vendors at once. Bind it to a hotkey (e.g. via Raycast/skhd) or just run it when you want to check usage.

## Vendor support matrix

| Vendor | Endpoint | What you see |
|---|---|---|
| **Anthropic** | `api.anthropic.com/api/oauth/usage` (undocumented) | Session (5h), Weekly (7d), Sonnet (7d), Extra usage $ |
| **OpenAI** | `chatgpt.com/backend-api/wham/usage` (undocumented; used by official `codex` CLI) | Codex 5h, Codex weekly, Code-review weekly, Credits |
| **Z.AI** | `api.z.ai/api/monitor/usage/quota/limit` (undocumented) | Session 5h, Weekly 7d, MCP tools monthly |
| **OpenRouter** | `openrouter.ai/api/v1/{credits,key}` (documented) | Balance, today/week/month spend, free vs paid tier |

### Endpoint stability

Three of the four endpoints are undocumented. The Anthropic and OpenAI endpoints are used by their official CLIs (`claude` and `codex`), so removing them would break those tools too. That makes them less shaky than scraped web endpoints. Z.AI's monitor endpoint is reverse-engineered from a third-party plugin; treat it as the most fragile one.

When an endpoint drifts, **run `make smoke`**. The live API tests check the exact fields this project depends on and produce a precise failure pointing at what changed. Paste the failure back into Claude Code and the affected `types.rs` can usually be updated mechanically.

## Format placeholders

### Shared / Anthropic (claudebar-compatible)

| Placeholder | Example |
|---|---|
| `{plan}` | `Max 5x` |
| `{session_pct}`, `{session_reset}`, `{session_bar}`, `{session_elapsed}` | `62`, `1h 30m`, `█████████████░░░░░░░`, `58` |
| `{session_pace}`, `{session_pace_indicator}`, `{session_pace_pct}`, `{session_pace_pts}`, `{session_pace_delta}`, `{session_pace_abs_delta}` | `↑`, `↑`, `12% ahead`, `4pts ahead`, `4`, `4` |
| `{weekly_*}` | same family for the 7d window |
| `{sonnet_*}` | same family for the 7d Sonnet window (empty when absent) |
| `{extra_spent}`, `{extra_limit}`, `{extra_pct}`, `{extra_bar}` | `$2.50`, `$50.00`, `5`, `█░░░░░░░░░░░░░░░░░░░` |

### OpenAI (Codex OAuth)

`{oai_plan}`, `{oai_session_pct}`, `{oai_session_reset}`, `{oai_session_elapsed}`, `{oai_session_pace}`, `{oai_session_pace_indicator}`, `{oai_weekly_*}` (same family), `{oai_code_review_pct}`, `{oai_credit_balance}`, `{oai_local_msgs}`, `{oai_cloud_msgs}`

### Z.AI

`{zai_plan}`, `{zai_session_pct}`, `{zai_session_reset}`, `{zai_weekly_pct}`, `{zai_weekly_reset}`, `{zai_mcp_pct}`, `{zai_mcp_reset}`

### OpenRouter

`{or_label}`, `{or_balance}`, `{or_total}`, `{or_used}`, `{or_used_today}`, `{or_used_week}`, `{or_used_month}`, `{or_consumed_pct}`, `{or_free_tier}`, `{or_limit}`, `{or_limit_remaining}`, `{or_balance_bar}`

## Local development

```bash
ai-usagebar --watch 5                              # iterate on --format live
ai-usagebar --vendor openrouter --format '{or_balance} · today {or_used_today}'

make test                                          # unit + integration
source ~/.config/zsh/secrets                       # only needed for live smoke
make smoke                                         # live API drift detection
make clippy                                        # cargo clippy -D warnings
```

## TUI controls

![ai-usagebar-tui showing the OpenAI tab — Codex 5h and weekly gauges, Credits block with message-count ranges, tabs at top, key hints in the footer](screenshots/tui-openai.png)

- `Tab` / `l` / `→` — next tab
- `Shift+Tab` / `h` / `←` — previous tab
- `r` — refresh active tab
- `R` — refresh all tabs
- `s` — open Settings overlay (primary vendor + API keys)
- `q` / `Esc` / `Ctrl-C` — quit

Auto-refresh runs every 60 seconds in the background. Vendors use the same layout. Here's OpenRouter showing the credit balance gauge (red because 98% is consumed), usage-by-period totals, and tier:

![ai-usagebar-tui showing the OpenRouter tab — Credit balance gauge at 98% in red ($13.67 left of $900), Usage by period with today/week/month, paid tier](screenshots/tui-openrouter.png)

### Settings overlay

![Settings overlay floating over the TUI — Primary vendor radio (Anthropic selected), masked Z.AI API key (•••), masked OpenRouter API key (•••), Save button, key hints at bottom](screenshots/tui-settings.png)

Press `s` while the TUI is open. The overlay lets you:

- Pick the **primary vendor** that the widget defaults to and that the TUI selects on startup. Use `←` / `→` to cycle.
- Enter your **Z.AI API key** and **OpenRouter API key** inline. Keys are masked as you type; press `Ctrl-V` to reveal or hide them. Env vars (`ZAI_API_KEY`, `OPENROUTER_API_KEY`) still win at runtime if they're set; the inline key is the fallback.

Key bindings inside the overlay:

- `Tab` / `↑↓` — move between fields
- `←` / `→` — cycle primary-vendor selection (only on the vendor field)
- `Ctrl-V` — toggle key visibility on the focused key field
- `Ctrl-S` — save and close
- `Esc` — discard and close

Save writes to `~/.config/ai-usagebar/config.toml` via `toml_edit` so your existing comments and unrelated fields are preserved. The file is automatically `chmod 600`ed on save, so inline keys aren't world-readable.

After save, the Settings overlay fires `SIGRTMIN+13` so any Waybar module configured with `signal: 13` refreshes immediately. You don't need to wait for the next 300-second interval or kick the bar by hand. The TUI's own tabs also re-fetch right away, so a freshly set API key takes effect on the spot.

If your module doesn't use `signal: 13`, the signal is a no-op and the bar will refresh on its next normal tick (up to `interval` seconds away). To force-refresh manually: `pkill -SIGUSR2 waybar` (full reload).

## Theming

- One Dark palette by default.
- Auto-merges with the active Omarchy theme at `~/.config/omarchy/current/theme/colors.toml`.
- Per-color overrides: `--color-low`, `--color-mid`, `--color-high`, `--color-critical` (claudebar-compatible).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the release history. Each release also has its own page at <https://github.com/akitaonrails/ai-usagebar/releases> with the auto-generated install snippet and checksum.

## Acknowledgements

The OpenAI and Anthropic OAuth endpoint references came from [`claudebar`](https://github.com/mryll/claudebar) and [`codexbar`](https://github.com/mryll/codexbar), both by mryll. The visual design, including the bordered Pango tooltip, severity colors, and pacing math, is theirs. This project is a Rust port with multi-vendor support.

## License

MIT.
