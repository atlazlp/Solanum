# Design: standalone Quickshell shell (`shell/`, config name `quantum-moon`)

## Rules
- Pure QML on Quickshell 0.3.2. NEVER `import Caelestia.*`. Imports: `Quickshell`, `Quickshell.Io`, `Quickshell.Wayland`,
  `Quickshell.Hyprland`, `Quickshell.Services.{Pipewire,Mpris,Notifications,SystemTray,Pam,UPower}`, `Quickshell.Widgets`,
  `Quickshell.DBusMenu`, `Quickshell.Networking`, `QtQuick`, `QtQuick.Layouts`, `QtQuick.Shapes`, `QtQuick.Effects`.
  Shell-local modules import as `qs.config`, `qs.theme`, `qs.components`, `qs.services`, `qs.utils`, `qs.modules.<x>`.
- Singletons: `pragma Singleton` + `import Quickshell` + `Singleton { ... }` and a `qmldir` per directory listing
  `singleton Name 1.0 Name.qml`.
- Layer namespaces: `quantum-moon-<module>` (WlrLayershell.namespace). GlobalShortcut appid `qm`.
- Config read-only from `~/.config/quantum-moon/shell.json` (+ `monitors/<name>.json` overrides), state in
  `~/.local/state/quantum-moon/`. The shell never writes shell.json except through `Config.save()` from Settings.
- Dev flags (`QM_SHELL_DEV=1`): no NotificationServer, no WlSessionLock/IdleMonitors, bar exclusionMode Ignore.
- Visual language: Nomai glyph / ship-log. Angular hexagons and chamfered rectangles (chamfer on top-left and
  bottom-right corners only), ink fills, 1 px glowing line in the planet primary, 6 px outer glow at 18%, corner ticks.
  No rounded pills, no blobs, no M3 ripples, no springs. Hover = line to 100% + fill ink2; press = lineSoft 14% for 90 ms.
  Headers: label font, textDim, uppercase, letter-spacing 2, preceded by a 3-segment zigzag divider.
  Panel open = GlyphReveal (children stagger 14 ms, max 12) + translate 24 px, 200 ms OutCubic; close 140 ms InCubic.

## Theme roles (from `state/scheme.json` -> `.colours`)
ink0 surfaceContainerLowest | ink surface | ink1 surfaceContainer | ink2 surfaceContainerHigh | ink3 surfaceContainerHighest |
scrim scrim@0.55 | line primary | lineSoft primaryContainer | lineDim outlineVariant | glow primary@0.18 |
text onSurface | textDim onSurfaceVariant | textOnLine onPrimary | ember peach ?? #e9a23b | spark tertiary |
danger error / onDanger onError | success success ?? green | warn yellow | term[0..15] term0..term15.
Fonts: display "Orbitron" (fallback Rubik), body "Rubik", mono "JetBrainsMono NF", icon "Material Symbols Rounded".
Sizes label 10 small 11 body 13 large 15 title 18 display 42 (x appearance.fontScale). Spacing xs 4 sm 6 md 10 lg 14 xl 20.
Chamfer sm 6 md 10 lg 14. lineWidth 1, glowWidth 6, hexPip 10. Z: bar 10 popout 20 panel 30 modal 40 toast 50 lock 100.
Motion: fast 110, normal 180, slow 260, reveal 420 ms; enter OutCubic, exit InCubic, slide OutQuart, spin InOutQuint, fade InOutQuad.

## Screens
`screens.roles = { main: "DP-2", left: "HDMI-A-1", right: "DP-3" }`; `modules` matrix maps module -> roles or "*".
Today: bar/main only; dashboard main+right; sidebar main; utilities main+right; launcher *; quantumMoon main;
notifications main; lock.fullUi main; hover.launcher main+right. Hotplug may promote another screen to main at runtime
(`state/screens-runtime.json`).

## IPC targets
launcher toggle|open <mode>|close|interrupt; lock lock|unlock|isLocked; drawers toggle|open|close <name>|closeAll|list;
gameMode set <bool>|isEnabled|toggle; monitors hotplug <name> <bool>; kvm capture <bool>|isCaptured|daemon <bool>|clipboard <bool>;
toast info|success|warn|error <title> <msg> <icon>; audio volumeUp|volumeDown|muteToggle|micMuteToggle|cycleOutput|
analogSpeakers|analogHeadphones|reloadMic|setVolume; brightness get|set|getFor|setFor; mpris playPause|next|previous|stop|
getActive|list; picker open|openFreeze|openClip|openFreezeClip|screen|window; record start <mode>|stop|togglePause|isRunning;
qm random|instant|apply <slug>|lock|unlock|isLocked|current; nightlight toggle|set <K>|isEnabled; notifs clear|toggleDnd|
enableDnd|disableDnd|isDndEnabled; shiplog open|search|markAllRead; updates refresh|run|count; services refresh|llm <start|stop>|
openWebui; vpn toggle|connect|disconnect|isConnected; hypr refreshDevices; idleInhibitor toggle|enable|disable|isEnabled;
git refresh|open; controlCenter open.
GlobalShortcuts (appid qm): launcher, launcherInterrupt, lock, unlock, session, sidebar, shipLog, dashboard, utilities,
quantumMoon, windowPicker, clearNotifs, showall, refreshDevices, mediaToggle, mediaNext, mediaPrev, mediaStop,
brightnessUp, brightnessDown, screenshot, screenshotFreeze.

## Drawer names
launcher, windowPicker, dashboard, sidebar, shipLog, session, utilities, quantumMoon, osd, services, kvm, audio, updates, settings.

## Caelestia C++ replacements
Config plugin -> config/Config.qml (FileView + JS deep merge). LogindManager -> services/Logind.qml (`gdbus monitor`).
HyprDevices -> `hyprctl devices -j` on qm:refreshDevices + `activelayout>>` raw event. Qalculator -> `qalc -t`.
Requests -> `curl -sf`. Toaster -> services/Toaster.qml. CUtils -> grabToImage/cp/rm. AppDb -> AppIndex.qml + JSON.
Cava/BeatTracker -> PwNodePeakMonitor (+ optional cava process). ArcGauge/Sparkline/VisualiserBars -> Shapes/Canvas.
Blobs -> dropped. ImageAnalyser -> not needed.

## Existing logic to port verbatim (read before writing)
- `patches/quickshell-caelestia/services/QuantumMoon.qml` (state machine, lock-marker rules, timings)
- `patches/quickshell-caelestia/modules/drawers/QuantumMoonPanel.qml` (geometry: ring btnSize*5.8, planets 80 px on
  106 px radius, angle -pi/2 + pi*i/4, QM button 52 px, eye 120 px, scout lock 40 px -> 16:9 bar)
- `patches/quickshell-caelestia/services/QuantumMoonWallpaper.qml` (slot assignment by monitor rank; centre = index 1)
- `patches/quickshell-caelestia/modules/IdleMonitors.qml`, `modules/lock/LockSurface.qml`, `~/.config/quickshell/caelestia/modules/lock/Pam.qml`
- `patches/quickshell-caelestia/services/{BarVpn,GitWatcher,KvmCapture,GameMode,Audio,LauncherItemOverrides}.qml`
- `patches/quickshell-caelestia/modules/bar/popouts/{GitWatcher,GitWatcherConfig}.qml`, `modules/windowpicker/*`
- `~/.config/quickshell/caelestia/services/{Colours,Brightness,Players,SystemUsage,Weather,Notifs,NotifData}.qml`
- `~/.config/quickshell/caelestia/utils/scripts/{fuzzysort.js,fzf.js}` (copy), `assets/pam.d/*` (copy)
