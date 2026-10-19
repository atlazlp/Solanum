# `~/.config/solanum/shell.json` keys

One line per key. `monitors/<name>.json` files hold the same shape and are deep-merged over this file for that screen.

- `screens.roles.{main,left,right}` : monitor connector name for each role (bar, notifications and the Solanum panel follow `main`; hotplug may promote another screen at runtime).
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
- `bar.width` : left bar width in px (exclusive zone on `main`).
- `bar.height` : legacy; unused by the left bar (kept for older configs).
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
- `sidebar.showOnHover` : open the Signals sidebar from the bottom-right hover strip.
- `audio.showOnHover` : open the volume panel from the right-middle hover strip.
- `modules.hover.audio` : roles where the right-edge volume hover is enabled.
- `launcher.maxShown` : rows visible in the result list.
- `launcher.prefixes.{apps,windows,clip,emoji,calc}` : typed prefixes that switch launcher mode.
- `launcher.favourites[]` : desktop ids pinned to the top.
- `launcher.hidden[]` : desktop ids never listed.
- `notifs.actionOnClick` : clicking a popup triggers its default action.
- `notifs.defaultTimeout` : ms before a popup without its own timeout closes (`0` keeps it up).
- `notifs.criticalTimeout` : ms before a critical popup closes (`0` stays until dismissed).
- `shiplog.maxEntries` : notification history cap.
- `shiplog.retentionDays` : history entries older than this are dropped.
- `session.commands.{logout,lock,suspend,hibernate,reboot,shutdown}` : argv arrays run by the session drawer.
- `session.icons.<action>` : material icon override for a session button.
- `quantumMoon.enabled` : show the Quantum Moon planet panel.
- `quantumMoon.showOnHover` : open the Solanum panel from its hover strip.
- `quantumMoon.shuffleOnIdle` : random planet on resume/idle return when not scout-locked.
- `quantumMoon.background.desktopClock.{enabled,position}` : desktop clock overlay.
- `quantumMoon.background.visualiser.{enabled,bars,ringMode,fixedPlanet}` : sound-wave bars on the wallpaper. `ringMode` is `follow_solanum` or `fixed`.
- `quantumMoon.background.centerMode` : `scene` (live Godot solar system; the Eye still uses its video) or `video` (recorded centre video on every planet). Default `scene`.
- `quantumMoon.background.sceneSpeed` : orbit time scale (default `4`, `1` matches the game loop).
- `quantumMoon.background.sceneRoot` : optional path to a Godot project. Empty uses `<engine>/scene`. A `godot-root` file beside `shell.json` overrides both.
- `updates.interval` : seconds between `qm-update --check` runs.
- `nightlight.temperature` : hyprsunset Kelvin used when no per-planet value applies.
- `gameMode.autoVpnOff` : disconnect the VPN when game mode turns on.
- `gameMode.pauseVideo` : pause mpvpaper over IPC while game mode is on.
- `utilities.toasts.{configLoaded,vpnChanged,gameModeChanged,audioOutputChanged,audioInputChanged,capsLockChanged,numLockChanged,kbLayoutChanged,nowPlaying}` : shell toast switches.
- `updates.{interval,checkOnResume,toast}` : seconds between update checks, whether to check on wake, and whether a toast fires when the count changes.
- `dashboard.weather.{location,unit}` : open-meteo lookup ("" = IP geolocation) and `C`/`F`.
- `qm.root` : override for the engine root (default: contents of `~/.config/solanum/root`).

Separate files: `vpn.json {enabled, connectionName, displayName}`, `git-watcher.json` (see `git-watcher.json.example`),
`services.json {llm:{controlScript, ollamaUrl, webuiUrl, composeDir}, kvm:{launchScript, clipboardScript, logPath}}`.
