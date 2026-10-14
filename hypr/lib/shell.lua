-- lib/shell.lua: the ONE place that knows which Quickshell config the binds talk to.
-- Phase 3 cutover = swap the active block below for the quantum-moon one (nothing else changes).
local U = QM.util
local S = {}

-- ============================ Phase 1: Caelestia shell (inactive, flip back by swapping the comment blocks) ============================
-- S.appid = "caelestia"
-- S.ipc = function(target, fn, ...)
--   local args = table.pack(...)
--   local tail = args.n > 0 and (" " .. table.concat(args, " ", 1, args.n)) or ""
--   return "qs -c caelestia ipc call " .. target .. " " .. fn .. tail
-- end
-- S.start = "caelestia shell -d"
-- S.kill = "qs -c caelestia kill"
-- hypr-user.conf:9 restart bind, with `hyprctl hyprpaper reload || hyprpaper` (always fell through and
-- left two hyprpaper processes) replaced by a clean restart of hyprpaper.
-- S.restart = [[sh -c 'qs -c caelestia kill; sleep 0.35; caelestia shell -d; sleep 0.5; pkill -x hyprpaper; hyprpaper & f="${HOME}/.config/caelestia/quantum-moon-root"; [ -f "$f" ] && read -r QM < "$f" && [ -n "$QM" ] && [ -f "$QM/scripts/qm-video-sync-from-state" ] && bash "$QM/scripts/qm-video-sync-from-state"']]
-- S.global = function(name) return "caelestia:" .. name end
-- caelestia-cli commands kept as exec strings until qm-* tools replace them (Phase 5/6).
-- S.screenshot = "caelestia screenshot"
-- S.record = "caelestia record"
-- S.clipboard = "pkill fuzzel || caelestia clipboard"
-- S.clipboard_delete = "pkill fuzzel || caelestia clipboard -d"
-- S.emoji = "pkill fuzzel || caelestia emoji -p"

-- ============================ Phase 3: quantum-moon shell (ACTIVE) ============================
S.appid = "qm"
S.ipc = function(target, fn, ...)
  local args = table.pack(...)
  local tail = args.n > 0 and (" " .. table.concat(args, " ", 1, args.n)) or ""
  return "qs -c quantum-moon ipc call " .. target .. " " .. fn .. tail
end
S.start = "qs -c quantum-moon -d"
S.kill = "qs -c quantum-moon kill"
S.restart = U.BIN .. "/qm-restart-shell"
S.global = function(name) return "qm:" .. name end
S.screenshot = U.BIN .. "/qm-screenshot"
S.record = U.BIN .. "/qm-record"
S.clipboard = U.BIN .. "/qm-clip"
S.clipboard_delete = U.BIN .. "/qm-clip -d"
S.emoji = U.BIN .. "/qm-emoji"

-- Derived IPC strings used by binds/features (same in both phases).
S.launcher_toggle = S.ipc("drawers", "toggle", "launcher")
S.window_picker = S.ipc("drawers", "toggle", "windowPicker")
S.lock = S.ipc("lock", "lock")
S.is_locked = S.ipc("lock", "isLocked")
-- Caelestia has gameMode enable|disable (no `set`); the quantum-moon shell adds `set <bool>`.
S.game_mode = function(on) return S.ipc("gameMode", on and "enable" or "disable") end
-- `monitors hotplug <host>` only exists in the quantum-moon shell; Caelestia ignores the unknown target.
S.monitors_hotplug = function(host) return S.ipc("monitors", "hotplug", host) end

QM.shell = S
return S
