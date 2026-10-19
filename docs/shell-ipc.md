# Shell IPC and global shortcuts

Call with `qm-shell <target> <function> [args]` (= `qs -c solanum ipc call ...`). Generated from `qs -c solanum ipc show`.

```
target updates
  function run(): void
  function refresh(): void
  function popout(): void
  function count(): int
target kvm
  function capture(on: bool): void
  function clipboard(on: bool): void
  function isCaptured(): bool
  function daemon(on: bool): void
target vpn
  function connect(): void
  function isConnected(): bool
  function toggle(): void
  function disconnect(): void
target notifs
  function toggleDnd(): void
  function clear(): void
  function enableDnd(): void
  function injectLow(summary: string, body: string, app: string): string
  function isDndEnabled(): bool
  function disableDnd(): void
  function injectUrgent(summary: string, body: string, app: string): string
  function inject(summary: string, body: string, app: string): string
  function count(): int
target services
  function status(): string
  function refresh(): void
  function llm(action: string): string
  function openWebui(): void
target toast
  function warn(title: string, message: string, icon: string): void
  function success(title: string, message: string, icon: string): void
  function info(title: string, message: string, icon: string): void
  function error(title: string, message: string, icon: string): void
target audio
  function micMuteToggle(): void
  function muteToggle(): void
  function analogSpeakers(): void
  function setVolume(value: string): string
  function isMuted(): bool
  function cycleOutput(): void
  function volumeUp(): void
  function analogHeadphones(): void
  function reloadMic(): void
  function getVolume(): real
  function volumeDown(): void
target monitors
  function main(): string
  function hotplug(name: string, connected: bool): string
target picker
  function screen(): void
  function openClip(): void
  function openFreezeClip(): void
  function window(): void
  function open(): void
  function openFreeze(): void
target drawers
  function list(): string
  function closeAll(): void
  function toggle(drawer: string): void
  function close(drawer: string): void
  function open(drawer: string): void
target idleInhibitor
  function isEnabled(): bool
  function toggle(): void
  function disable(): void
  function enable(): void
target qm
  function instant(): void
  function apply(slug: string): void
  function lock(): void
  function isLocked(): bool
  function random(): void
  function unlock(): void
  function current(): string
target lock
  function lock(): void
  function isLocked(): bool
  function preview(seconds: int): void
  function unlock(): void
target record
  function start(mode: string): string
  function togglePause(): void
  function isRunning(): bool
  function stop(): void
target gameMode
  function isEnabled(): bool
  function set(on: bool): void
  function toggle(): void
  function disable(): void
  function enable(): void
target controlCenter
  function open(): void
target hypr
  function refreshDevices(): void
target launcher
  function interrupt(): void
  function toggle(): void
  function close(): void
  function mode(): string
  function open(mode: string): void
target brightness
  function getFor(query: string): real
  function get(): real
  function set(value: string): string
  function setFor(query: string, value: string): string
target shiplog
  function reveal(id: string): void
  function markAllRead(): void
  function unread(): int
  function clear(): void
  function search(q: string): void
  function edges(): string
  function select(app: string): void
  function count(): int
  function open(): void
target git
  function refresh(): void
  function popout(): void
  function state(): string
  function open(): void
target mpris
  function getActive(prop: string): string
  function previous(): void
  function list(): string
  function play(): void
  function playPause(): void
  function stop(): void
  function next(): void
  function pause(): void
target nightlight
  function isEnabled(): bool
  function set(kelvin: int): void
  function toggle(): void
  function disable(): void
  function enable(): void
```

## Global shortcuts (Hyprland `global, qm:<name>` / Lua `hl.dsp.global("qm:<name>")`)

- `qm:brightnessDown`
- `qm:brightnessUp`
- `qm:clearNotifs`
- `qm:dashboard`
- `qm:launcher`
- `qm:launcherInterrupt`
- `qm:lock`
- `qm:mediaNext`
- `qm:mediaPrev`
- `qm:mediaStop`
- `qm:mediaToggle`
- `qm:quantumMoon`
- `qm:refreshDevices`
- `qm:screenshot`
- `qm:screenshotFreeze`
- `qm:session`
- `qm:shipLog`
- `qm:showall`
- `qm:sidebar`
- `qm:unlock`
- `qm:utilities`
- `qm:windowPicker`

## Shell to Hyprland

The shell emits `hyprctl dispatch event qm:<topic>:<payload>` (topics: `gamemode`, `launcher`, `lock`); the Lua config listens on the event socket.
