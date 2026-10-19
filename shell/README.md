# solanum shell (`shell/`)

Standalone Quickshell 0.3.2 configuration. Pure QML: no `import Caelestia.*` anywhere.
Design rules, theme roles and the IPC/shortcut surface are defined in `docs/dev/design-shell.md`;
this file documents how the code is organised and the contracts later modules must follow.

## Running

```sh
# dev mode, side by side with another shell (nothing exclusive is claimed, bar reserves no space)
QM_SHELL_DEV=1 qs -c solanum
qs -c solanum ipc show          # list IPC targets
qs -c solanum ipc call drawers toggle dashboard
qs -c solanum kill
```

`~/.config/quickshell/solanum` is a symlink to this directory. Config lives in
`~/.config/solanum/` (`shell.json`, `monitors/<name>.json`, `vpn.json`, `root`), state in
`~/.local/state/solanum/` (`scheme.json`, `current.json`, `screens-runtime.json`, ...).

`DevFlags.dev` (from `QM_SHELL_DEV`) gates: `notificationServer`, `sessionLock`, `idleMonitors`,
`barExclusive`. Modules that claim exclusive protocols must check the matching flag.

## Layout

```
shell.qml                 ShellRoot: Drawers, Bars, Shortcuts, IpcRoot + placeholder Loaders
config/    qs.config      Config, Paths, Screens, DevFlags singletons; Defaults.js
theme/     qs.theme       Theme (colours/fonts/sizes), Motion (durations/easings), Glyphs.js (SVG paths)
components/ qs.components Nomai* / Hex* / Glyph* widgets (see below)
utils/     qs.utils       Icons singleton, Fmt.js
services/  qs.services    one singleton per concern + DrawerVisibilities type
modules/
  drawers/  qs.modules.drawers   DrawerWindow per screen, Panels (slots), Regions (input mask), HoverStrips, Toasts
  bar/      qs.modules.bar       BarWindow per screen, Bar row, segments/, popouts/
  osd/      qs.modules.osd       Osd (slot content), OsdWatcher (per screen trigger)
  Shortcuts.qml, IpcRoot.qml     qs.modules
```

Conventions: `pragma Singleton` + `Singleton {}` + `qmldir` entry per directory; every file that
reaches another directory imports it as `qs.<dir>`. Layer namespaces are `solanum-<module>`.
GlobalShortcut appid is `qm`. All colours come from `Theme`, all timings from `Motion`.

## Adding a panel (drawer)

Drawer names: `launcher, windowPicker, dashboard, sidebar, shipLog, session, utilities, quantumMoon,
osd, services, kvm, audio, updates, settings`. Each is a bool on `DrawerVisibilities` (one per screen)
and has a slot in `modules/drawers/Panels.qml` that loads a file from a well-known path:

| drawer        | file                                   | position                 |
|---------------|----------------------------------------|--------------------------|
| dashboard     | `modules/dashboard/Dashboard.qml`      | top centre               |
| quantumMoon   | `modules/quantummoon/QmPanel.qml`      | top right                |
| notifications | `modules/notifications/Popups.qml`     | top right (below QM)     |
| osd           | `modules/osd/Osd.qml` (exists)         | right, vertical centre   |
| session       | `modules/session/Session.qml`          | right, vertical centre   |
| sidebar       | `modules/sidebar/Sidebar.qml`          | right, full height       |
| utilities     | `modules/utilities/Utilities.qml`      | bottom right             |
| launcher      | `modules/launcher/Launcher.qml`        | bottom centre            |
| windowPicker  | `modules/windowpicker/WindowPicker.qml`| bottom centre            |
| shipLog       | `modules/shiplog/ShipLog.qml`          | centre                   |
| services      | `modules/panels/ServicesPanel.qml`     | centre                   |
| kvm           | `modules/panels/KvmPanel.qml`          | centre                   |
| audio         | `modules/panels/AudioPanel.qml`        | centre                   |
| updates       | `modules/updates/UpdatesPanel.qml`     | centre                   |
| settings      | `modules/settings/Settings.qml`        | centre                   |

Drop a file at the path and it is live: the slot `Loader` activates when the drawer opens and unloads
after the close animation (140 ms). A missing file only logs `Panels: no panel at ...`.

Panel root item contract:
- Give it `implicitWidth`/`implicitHeight` (the slot sizes itself from them).
- Optionally declare plain properties `property var screen`, `property var visibilities`,
  `property var slot` -- the slot assigns them after load (`ShellScreen`, `DrawerVisibilities`,
  the slot Item). Do not make them `required`.
- Optionally declare `function reveal()`; it is called after load (use it to `trigger()` a `GlyphReveal`).
- The slot already animates opacity + 24 px translate (200 ms OutCubic / 140 ms InCubic). Use
  `GlyphReveal` inside for the staggered write-in of children.
- Keyboard: `DrawerVisibilities.wantsKeyboard` flips the drawers window to `OnDemand` focus when
  launcher/windowPicker/session/settings/shipLog/kvm/audio/services/updates is open; call
  `forceActiveFocus()` on your input. Escape at window level calls `visibilities.closeAll()`.
- Input only reaches what `Regions.qml` masks: every visible slot, the popout host, hover strips and toasts.
  If you add a new slot, add a `Region { item: ... }` line there.

Opening/closing from anywhere: `Visibilities.toggle(name, vis)`, `.open(name, vis)`, `.close(name, vis)`,
`.closeAll()`; pass `null` for `vis` to target the focused screen. Exclusive drawers close each other.
Hover opening is handled by `HoverStrips.qml` (matrix keys `hover.dashboard|quantumMoon|launcher|sidebar`,
disabled under GameMode, KvmCapture and fullscreen).

### Bar popouts
`modules/bar/popouts/PopoutHost.qml` lives in the drawers window under the bar. Segments call
`Visibilities.popoutFor(screen.name).show(name, absX, width, data, sticky)` with the segment's absolute
x (bar and drawers windows share the screen origin). Known names: `audio`, `network`, `tray` (data =
SystemTrayItem as `payload`), `activewindow`. Add a name by adding a `Component` + `case` in `PopoutHost.qml`.
Popout content gets `host` assigned if it declares `property var host`.

## Singletons (`qs.services`)

| singleton     | owns                                                                    | IPC target |
|---------------|-------------------------------------------------------------------------|------------|
| Hypr          | Hyprland monitors/workspaces/toplevels, `activeToplevel`, `focusedMonitor`, keyboard (`capsLock`, `numLock`, `kbLayout`) via `hyprctl devices -j`, `dispatch()`, `emit(topic,payload)` -> `qm:<topic>:<payload>` event, `hasFullscreenOn(screen)`, `event(name,data)` signal | `hypr refreshDevices` |
| Visibilities  | per-screen `DrawerVisibilities` registry, `getForActive()`, `forScreen(name)`, open/close/toggle/closeAll, popout registry | `drawers toggle/open/close/closeAll/list` |
| Toaster       | `toasts` list, `toast(title,msg,icon,type,timeout)`, `dismiss(id)`        | `toast info/success/warn/error` |
| Audio         | Pipewire sink/source, `volume/muted/sourceVolume/sourceMuted`, `sinks/sources/streams`, `setVolume/incrementVolume/...`, analog port (`analogActivePort`, `setAnalogSpeakers/Headphones`), `reloadMicrophone()`, `peak` (bump `peakRefs` to enable) | `audio volumeUp/volumeDown/muteToggle/micMuteToggle/cycleOutput/analogSpeakers/analogHeadphones/reloadMic/setVolume/getVolume/isMuted` |
| Brightness    | `monitors` (one per ShellScreen: `brightness`, `setBrightness(v)`), `getMonitorForScreen()`, `increase/decreaseBrightness()` | `brightness get/set/getFor/setFor` |
| Network       | `connected`, `wired`, `wifi`, `ssid`, `strength`, `icon`, `label` (Quickshell.Networking, nmcli fallback) | - |
| BarVpn        | `configured`, `connected`, `busy`, `displayName`, `toggle/connect/disconnect()` (`vpn.json`) | `vpn toggle/connect/disconnect/isConnected` |
| GameMode      | `enabled` (persistent), `toggle()/set()`, hyprctl keywords, resources script, emits `qm:gamemode` | `gameMode set/enable/disable/isEnabled/toggle` |
| KvmCapture    | `active`, `daemon`, `clipboard`, `setActive()` (closes drawers, hides bar) | `kvm capture/isCaptured/daemon/clipboard` |
| Players       | Mpris `list`, `active`, `manualActive`, `playPause/next/previous/stop()`, `getArtUrl()` | `mpris playPause/next/previous/stop/play/pause/getActive/list` |
| Time          | `date`, `timeStr` (HH:mm), `dateStr`, `format(fmt)`                      | - |
| Monitors      | writes `state/screens-runtime.json` on hotplug                           | `monitors hotplug <name> <bool>/main` |
| IdleInhibitor | real Wayland idle inhibitor, `enabled` (persistent)                      | `idleInhibitor toggle/enable/disable/isEnabled` |
| Idle          | placeholder: `inhibited`                                                 | - |
| NightLight    | `enabled`, `temperature`, `toggle()/set(K)` via `hyprctl hyprsunset`     | `nightlight toggle/set/isEnabled/enable/disable` |
| QuantumMoon   | STUB: `slug`, `displayName`, `logoPath`, `locked` from state files       | `qm current/isLocked/random/instant/apply/lock/unlock` |
| GitWatcher    | STUB: `configured=false`, `active=false`, `count=0`                      | `git refresh/open` |
| Updates       | STUB: `count=0`                                                          | `updates refresh/run/count` |
| Recorder      | STUB: `running=false`, `paused=false`                                    | `record start/stop/togglePause/isRunning` |
| Lock          | STUB: `locked=false`, `lock()/unlock()` log + signals                    | `lock lock/unlock/isLocked` |
| Screenshot    | STUB: `open(freeze, clipboard)` toasts                                   | `picker open/openFreeze/openClip/openFreezeClip/screen/window` |
| Notifs        | STUB: `dnd`, `count=0`, `clear()`                                        | `notifs clear/toggleDnd/enableDnd/disableDnd/isDndEnabled` |

Other targets: `launcher toggle/open <mode>/close/interrupt/mode` and `controlCenter open` live in
`modules/IpcRoot.qml` (the launcher panel should read `IpcRoot`'s `requestedMode` through the
`launcher mode` call or by giving the panel access to the drawer registry).
Still to be added by later phases: `shiplog`, `services`.

Replacing a stub: keep the IPC target name and the properties listed above; the bar's `Status.qml`
binds to them.

## Config (`qs.config`)

- `Config.<section>` mirrors `Defaults.js` deep-merged with `~/.config/solanum/shell.json`;
  `Config.forScreen(name)` / `Config.getFor(name, "a.b", fallback)` add `monitors/<name>.json`;
  `Config.save("a.b", value)` writes atomically; `Config.reload` signal fires after any change.
- `Screens.mainName`, `Screens.roleOf(name)`, `Screens.isEnabled(module, screenName)` evaluate the
  `modules` matrix (`"*"` or a list of roles / screen names). `state/screens-runtime.json` overrides main.
- `Paths.config/state/cache/data/scripts/qmRoot/modes/scheme/currentMode/screensRuntime`.

## Theme (`qs.theme`)

`Theme.ink0 ink ink1 ink2 ink3 scrim line lineSoft lineDim glow text textDim textOnLine ember spark
danger onDanger success warn term[]`, fonts `fontDisplay/fontBody/fontMono/fontIcon`, sizes
`sizeLabel..sizeDisplay`, spacing `spaceXs..spaceXl`, `chamferSm/Md/Lg`, `lineWidth`, `glowWidth`,
`hexPip`, z `zBar zPopout zPanel zModal zToast zLock`, helpers `alpha(c,a)`, `mix(a,b,t)`.
`Motion.fast/normal/slow/reveal/press/panelOpen/panelClose/glyphStagger` and easings
`enter/exit/slide/spin/fade`. `Glyphs.js`: `chamferRect(w,h,c,corners,inset)`, `hexagon`, `hexPip`,
`slantedSegment`, `arc`, `cornerTicks`, `zigzag`.

## Components (`qs.components`)

| component      | key props / signals |
|----------------|---------------------|
| NomaiFrame     | `shape` chamfer\|hex, `fill`, `lineColor`, `lineWidth`, `lineOpacity`, `chamfer`, `corners` (bitmask 1 tl, 2 tr, 4 br, 8 bl; default 5), `glow`, `ticks`, `padding`; children go inside |
| HexButton      | `icon`, `text`, `shape`, `active`, `danger`, `flat`, `glow`, `padding`, `tooltip`, `maxWidth` (elide label), `hovered`; `clicked()`, `rightClicked()`, `wheel(event)`; keyboard Return/Space |
| HexSegment     | bar segment: `ends` both\|left\|right\|none, `connector`, `hovered`, `active`, `interactive`, `padding`; `clicked(point)`, `rightClicked(point)`, `wheel(event)`, `entered()`, `exited()` |
| GlyphReveal    | wraps children; `trigger()` staggers opacity + translate; `autoTrigger`, `direction` |
| GlyphText      | `role` label\|small\|body\|large\|title\|display\|mono, `dim`, `animate` |
| GlyphIcon      | `icon`, `fill` 0..1, `weight`, `size`, `animate` (Material Symbols Rounded, variable axes) |
| NomaiSlider    | `value/from/to/step`, `orientation`, `icon`, `muted`, `accent`, `thickness`, `length`; `moved(value)` |
| NomaiSwitch    | `checked`, `label`; `toggled(checked)` |
| NomaiTextField | `text`, `placeholder`, `icon`, `forceFocus()`; `accepted()`, `escaped()` |
| NomaiList      | ListView with chamfered highlight + keys; `activated(index)` |
| NomaiDivider   | zigzag, `segments`, `color` |
| SectionHeader  | divider + uppercase label (`text`) |
| NomaiTooltip   | `text`, `show`, `delay` |
| NomaiMenu      | `menu` (QsMenuHandle), `menuWidth`; renders submenus with Back; `closed()` |
| NomaiMenuItem  | `entry` (QsMenuEntry); `triggered()`, `openSubmenu()` |
| Popout         | NomaiFrame with a stem; `anchorCenterX` |
| Modal          | `open`, `title`, `dismissOnScrim`; `dismissed()`; children centred over a scrim |
| AppIcon        | `appId`, `fallbackIcon`, `size` |
| ProgressArc    | `value`, `startAngle`, `sweep`, `thickness`, `accent` |
| Sparkline      | `values`, `max`, `accent`, `fillArea` |
| LevelBars      | `level`, `bars`, `accent` |

## Bar

`BarWindow` (per screen, shown where `modules.bar` allows; hidden over fullscreen when
`general.showOverFullscreen` is false and while KVM capture is active). `Bar.qml` builds the row from
`Config.bar.entries` ids: `logo workspaces spacer activeWindow tray clock status power`. Segment files
in `modules/bar/segments/` receive `screen` and `bar` (`bar.visibilities`, `bar.popouts`).
