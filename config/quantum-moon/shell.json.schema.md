# `~/.config/quantum-moon/shell.json` keys

One line per key. `monitors/<name>.json` files hold the same shape and are deep-merged over this file for that screen.

- `screens.roles.{main,left,right}` : monitor connector name for each role (bar/notifications/QM panel follow `main`; hotplug may promote another screen at runtime).
- `modules.<module>` : list of roles (or `["*"]`) a module is enabled on: `bar`, `dashboard`, `sidebar`, `utilities`, `launcher`, `quantumMoon`, `notifications`.
- `modules.lock.fullUi` : roles that draw the full lock UI (others show black + "press any key").
- `modules.hover.launcher` : roles where hovering the bottom edge opens the launcher.
- `appearance.fontScale` : multiplier for every font size.
- `appearance.padding.scale` : multiplier for spacing tokens.
- `appearance.transparency.{enabled,base}` : panel transparency switch and base alpha.
- `general.idle.inhibitWhenAudio` : skip idle actions while audio is playing.
- `general.idle.lockedSleepAfter` : seconds after a lock before the session suspends.
- `general.idle.timeouts[]` : `{timeout: seconds, idleAction: "lock" | [cmd, args...]}` entries.
- `general.showOverFullscreen` : allow drawers over fullscreen windows.
- `bar.height` : bar height in px (exclusive zone on `main`).
- `bar.entries[]` : ordered `{id, enabled}` segments: `logo`, `workspaces`, `spacer`, `activeWindow`, `tray`, `clock`, `statusIcons`, `power`.
- `bar.activeWindow.showOnHover` : show the active window popout on hover.
- `bar.popouts.{statusIcons,tray}` : enable popouts for those segments.
- `bar.showOnHover` : auto-hide bar, reveal on hover.
- `bar.status.show<Audio|Microphone|Network|Wifi|Bluetooth|Battery|Vpn|GitWatcher|Updates|GameMode|Kvm|NightLight|IdleInhibitor>` : status glyph toggles.
- `bar.tray.hiddenIcons[]` : tray item ids to hide (e.g. once a panel replaces a tray app).
- `bar.tray.iconSubs[]` : `{id, icon}` substitutions for tray icons.
- `bar.workspaces.perMonitorWorkspaces` : only show the workspaces of the bar's monitor.
- `bar.workspaces.shown` : number of workspace pips.
- `launcher.showOnHover` : open the launcher from the hover strip.
- `launcher.maxShown` : rows visible in the result list.
- `launcher.prefixes.{apps,windows,clip,emoji,calc}` : typed prefixes that switch launcher mode.
- `launcher.favourites[]` : desktop ids pinned to the top.
- `launcher.hidden[]` : desktop ids never listed.
- `notifs.actionOnClick` : clicking a popup triggers its default action.
- `notifs.defaultExpireTimeout` : ms before a popup without its own timeout closes.
- `notifs.expire` : whether popups auto-close at all.
- `shiplog.maxEntries` : notification history cap.
- `shiplog.retentionDays` : history entries older than this are dropped.
- `session.commands.{logout,lock,suspend,hibernate,reboot,shutdown}` : argv arrays run by the session drawer.
- `session.icons.<action>` : material icon override for a session button.
- `quantumMoon.enabled` : show the Quantum Moon planet panel.
- `quantumMoon.showOnHover` : open the panel from its hover strip.
- `quantumMoon.shuffleOnIdle` : random planet on resume/idle return when not scout-locked.
- `updates.interval` : seconds between `qm-update --check` runs.
- `nightlight.temperature` : hyprsunset Kelvin used when no per-planet value applies.
- `gameMode.autoVpnOff` : disconnect the VPN when game mode turns on.
- `gameMode.pauseVideo` : pause mpvpaper over IPC while game mode is on.
- `utilities.toasts.{configLoaded,vpnChanged,gameMode,hotplug}` : toast switches.
- `dashboard.weather.{location,unit}` : open-meteo lookup ("" = IP geolocation) and `C`/`F`.
- `qm.root` : override for the engine root (default: contents of `~/.config/quantum-moon/root`).

Separate files: `vpn.json {enabled, connectionName, displayName}`, `git-watcher.json` (see `git-watcher.json.example`),
`services.json {llm:{controlScript, ollamaUrl, webuiUrl, composeDir}, kvm:{launchScript, clipboardScript, logPath}}`.
