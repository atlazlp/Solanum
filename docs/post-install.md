# After install

## Keyboard and mouse

The full list is generated from the running compositor: `hyprctl binds -j | jq -r '.[] | "\(.modmask)\t\(.key)\t\(.description // .dispatcher) \(.arg)"'`. The ones you will use daily:

| Keys | Action |
|---|---|
| Super (tap) | Launcher. Super + anything else never opens it. |
| Super+T / W / C / E / G | kitty / Firefox / Cursor / Nautilus / GitHub Desktop |
| Super+D | Window picker |
| Super+N | Sidebar (notifications, DND, quick toggles) |
| Super+K | Show everything (all drawers) |
| Super+L / Super+Alt+L | Lock / restart shell and lock |
| Ctrl+Alt+Delete | Session menu |
| Super+1..0, Ctrl+Super+1..0 | Workspace in the current group / workspace group |
| Super+Alt+1..0, Ctrl+Super+Alt+1..0 | Move window there |
| Super+S | Toggle the `special` workspace |
| Super+Alt+S, Ctrl+Super+S, Ctrl+Super+Space | Move the focused window to/from the scratchpad |
| Alt+Tab / Shift+Alt+Tab | Cycle windows (display-line order, includes grouped tabs) |
| Super+Comma / U / Shift+Comma | Group toggle / leave group / lock group |
| Super+arrows, Super+Shift+arrows | Focus / move |
| Super+Minus/Equal, Super+Alt+arrows | Resize |
| Super+F / Alt+F / Alt+Space / P / Q | Fullscreen / maximize / float / pin / close |
| Super+Alt+Backslash | Picture-in-picture (float, quarter width, bottom-right, pinned) |
| Super+Shift+M | Random planet |
| Super+Shift+H | Toggle analog output (line-out / headphones) |
| Super+Shift+A | Activity monitor |
| Print, Super+Shift+S, Super+Shift+Alt+S | Screenshot: full / frozen region / region |
| Super+Alt+R, Ctrl+Alt+R, Super+Shift+Alt+R | Record with sound / silent / region (toggle) |
| Super+V, Super+Alt+V, Super+Period | Clipboard history / delete from history / emoji |
| Super+Shift+C | Colour picker |
| Super+Shift+L | Suspend then hibernate |
| Ctrl+Super+Alt+R | Restart the shell (and hyprpaper, and the centre video) |
| Mouse 4 held + LMB/RMB drag | Move / resize (inert inside a Steam game) |
| Mouse 5 held + LMB click | Group / ungroup |

Personal overrides go in `hypr/local.lua` (gitignored): keyboard layout, `follow_mouse`, cursor and group options, `QM.features.launcher.fallback_interrupts`.

## Monitors

`hypr/monitors.lua` declares the three outputs. `features/hotplug.lua` handles DP-2 going away: the remaining monitors are packed left to right, the rightmost becomes the shell's main screen (bar, notifications, Quantum Moon panel, full lock UI) and the wallpapers are re-placed. Plugging DP-2 back restores the defaults.

The shell's per-screen module matrix lives in `~/.config/quantum-moon/shell.json` under `screens.roles` and `modules` (see `config/quantum-moon/shell.json.schema.md`). With one or two monitors set `roles.main` to the output you have; the engine assigns wallpaper slots by x position (`slot-0`, `slot-1`, `slot-2`), the centre slot gets the video when there are at least two outputs.

## Planets

`qm-apply <slug>` (brittle-hollow, dark-bramble, giants-deep, hourglass-twins, timber-hearth, eye-of-the-universe), `qm-random`, or the panel. Each mode has `palette.json`, `meta.json` (display name, `nightTemperature`), `logo.png`, `wallpapers/slot-{0,1,2}.png` and an optional `center.mp4`. The engine writes `~/.local/state/quantum-moon/scheme.json` (the shell theme), `scheme.lua` (Hyprland colours and night light, applied through `hyprctl reload`), kitty colours (live), GTK3/4 and libadwaita CSS, a KDE colour scheme and a qt6ct palette.

The scout lock (top-right of the panel) pins the planet: idle shuffles, pre-lock and pre-sleep shuffles are skipped while locked.

## Night light

`hyprsunset` runs as a user unit; `features/night.lua` applies the planet's temperature from 19:00 to 07:00 and identity otherwise. The utilities card has a slider and toggle (`qm-shell nightlight toggle|set <K>`), which writes `~/.local/state/quantum-moon/nightlight.json` as an override.

## VPN

`~/.config/quantum-moon/vpn.json`: `{ "enabled": true, "connectionName": "<nmcli name>", "displayName": "..." }`. The bar glyph shows the state, click toggles `nmcli connection up|down`. Game mode disconnects it when `gameMode.autoVpnOff` is true.

## PR watcher (Azure DevOps)

`~/.config/quantum-moon/git-watcher.json` (mode 600, holds the PAT). The `quantum-moon-git-watcher` unit runs the daemon; the bar glyph turns ember when a PR is overdue or you are mentioned, the popout lists the feed and the archive, and the config modal edits the file and reloads the daemon (SIGHUP). Discord-first mode holds new-PR alerts until the link is posted in a watched channel.

## Updates

The bar shows a glyph with the count from `checkupdates` + `yay -Qua` (every 30 min and after resume). The popout lists packages; "Update now" opens a kitty window running the update. `qm-update --check` prints the same data as JSON.

## Backups

`qm-backup init` once, then the `quantum-moon-backup.timer` runs `qm-backup run` daily at 03:30 (only when `/mnt/Backup` is mounted). Excludes are in `~/.config/quantum-moon/backup-patterns.txt`. `qm-backup list|mount <dir>|check|prune`. After every pacman transaction the hook writes package lists to `/var/lib/quantum-moon/`, which the backup includes.

## Services and KVM panels

`~/.config/quantum-moon/services.json` points the Docker/Ollama/Open WebUI panel at your control script and URLs, and the KVM panel at the lan-mouse launch and clipboard-sync scripts. Both panels replace the earlier Python tray icons; the `lan-mouse` and `llm-tray` units still start the daemons.

## Game mode

Hyprland Lua detects a visible or fullscreen `steam_app_*` / gamescope / `content_type = game` window: it writes `$XDG_RUNTIME_DIR/quantum-moon-game-mode.active`, pauses the wallpaper video over mpv IPC and tells the shell, which hides hover drawers and shows a glyph with an exit button. Leaving the game reverses it.

## Lock and idle

The shell locks after 30 minutes idle and suspends after 35 (`general.idle` in `shell.json`), never while audio plays (`quantum-moon-audio-inhibit`). Unlocked and idle, the planet shuffles before the lock. `locked-sleep-after.sh` suspends N seconds after a manual lock. Emergency: `Super+Ctrl+Alt+L` restarts the shell and re-locks; `hl.clear_crashed_lockscreen` is bound in the Lua config.
