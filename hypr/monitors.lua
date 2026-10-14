-- monitors.lua: default triple-head layout (hypr-monitors-default.conf) + fallback for unknown outputs.
-- features/hotplug.lua re-specs these at runtime when the preferred main (DP-2) is unplugged.
local M = {}

M.preferred_main = "DP-2"
M.default = {
  { output = "HDMI-A-1", mode = "1366x768@59.79", position = "0x0", scale = 1, transform = 1 },
  { output = "DP-2", mode = "1920x1080@143.99", position = "768x0", scale = 1 },
  { output = "DP-3", mode = "1366x768@59.79", position = "2688x312", scale = 1 },
}

-- Anything else: preferred mode, auto position, scale 1 (hyprland.conf:17).
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

function M.apply_default()
  for _, spec in ipairs(M.default) do hl.monitor(spec) end
end

M.apply_default()

QM.monitors = M
return M
