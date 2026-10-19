-- Quantum Moon: Hyprland 0.56.2 native Lua config (port of the Caelestia hyprlang tree).
--
-- Verify without starting a compositor (must print "config ok"):
--   Hyprland --verify-config -c /home/lpacheco/Projects/Quantum-Moon/hypr/hyprland.lua
--
-- Rules of the road (see hypr/README.md and docs/dev/design-lua.md):
--   * never call hl.exec_cmd or hl.timer at load time: both segfault under --verify-config and
--     top-level exec re-runs on every reload. One-shots go in hl.on("hyprland.start"), repeat
--     timers go through QM.util.on_live (start + every reload).
--   * everything that talks to the Quickshell shell goes through lib/shell.lua (one-file flip).
--   * colours come from lib/scheme.lua (~/.local/state/solanum/scheme.lua written by qm-apply).

QM = QM or {}
QM.features = QM.features or {}

require("lib/util")
require("lib/shell")
require("lib/scheme")

require("env")
require("monitors")
require("general")
require("decoration")
require("animations")
require("input")
require("group")
require("workspaces")
require("rules")
require("binds/init")

for _, name in ipairs({ "alttab", "special", "launcher_super", "proton_ghosts", "hotplug", "gamemode", "telegram", "night", "pip", "hyprwinwrap" }) do
  local ok, err = pcall(require, "features/" .. name)
  if not ok then
    QM.util.log("feature " .. name .. " failed to load: " .. tostring(err))
    hl.notification.create({ text = "QM feature " .. name .. ": " .. tostring(err), timeout = 8000 })
  end
end

require("autostart")

-- Machine-local overrides (hypr/local.lua, gitignored; see local.lua.example).
local ok_local, err_local = pcall(require, "local")
if not ok_local and not tostring(err_local):find("not found", 1, true) then
  hl.notification.create({ text = "QM local.lua: " .. tostring(err_local), timeout = 8000 })
end
