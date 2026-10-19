-- hyprwinwrap: pin the Godot solar wallpaper to the background layer on the
-- centre monitor (same slot as mpvpaper: monitors sorted by x,y → index 1 when
-- there are 2+ outputs). Upstream: https://github.com/gen3vra/hyprwinwrap
-- Build: make -C hypr/plugins/hyprwinwrap
--
-- window() must run during config evaluation (this file's require), not in
-- on_live — the plugin clears Lua specs at the start of every reload.
local U = QM.util

local CLASS = "qm-solar-wallpaper"
local SO = U.CFG_DIR .. "/plugins/hyprwinwrap/hyprwinwrap.so"

local function already_loaded()
  local ok, plugins = pcall(function()
    return hl.get_loaded_plugins()
  end)
  if not ok or type(plugins) ~= "table" then
    return false
  end
  for _, p in ipairs(plugins) do
    local name = U.field(p, "name") or ""
    local path = tostring(U.field(p, "path") or "")
    if name == "hyprwinwrap" or path:find("hyprwinwrap", 1, true) then
      return true
    end
  end
  return false
end

local function load_plugin()
  if not U.exists(SO) then
    U.log("hyprwinwrap.so missing — run: make -C " .. U.CFG_DIR .. "/plugins/hyprwinwrap")
    return false
  end
  if already_loaded() then
    return true
  end
  local ok_mon, mons = pcall(function()
    return hl.get_monitors()
  end)
  if not ok_mon or type(mons) ~= "table" or #mons == 0 then
    return false
  end
  local ok, err = pcall(function()
    hl.plugin.load(SO)
  end)
  if not ok then
    U.log("hyprwinwrap load failed: " .. tostring(err))
    return false
  end
  return true
end

-- Same centre-slot rule as qm-video-lib / QuantumMoonWallpaper.
local function center_monitor_name()
  local ok, mons = pcall(function()
    return hl.get_monitors()
  end)
  if not ok or type(mons) ~= "table" or #mons == 0 then
    return nil
  end
  local list = {}
  for _, m in ipairs(mons) do
    list[#list + 1] = m
  end
  table.sort(list, function(a, b)
    local ax, bx = tonumber(U.field(a, "x")) or 0, tonumber(U.field(b, "x")) or 0
    if ax ~= bx then
      return ax < bx
    end
    return (tonumber(U.field(a, "y")) or 0) < (tonumber(U.field(b, "y")) or 0)
  end)
  local idx = (#list >= 2) and 2 or 1
  return U.field(list[idx], "name")
end

if load_plugin() then
  local wrap = hl.plugin and hl.plugin.hyprwinwrap
  local window_fn = wrap and wrap.window
  if type(window_fn) == "function" then
    local mon = center_monitor_name()
    local spec = {
      class = CLASS,
      layer = 0,
      pos_x = 0,
      pos_y = 0,
      size_x = 100,
      size_y = 100,
    }
    if mon and mon ~= "" then
      spec.monitor = mon
    end
    local ok, err = pcall(window_fn, spec)
    if not ok then
      U.log("hyprwinwrap.window failed: " .. tostring(err))
    else
      U.log("hyprwinwrap: class=" .. CLASS .. " monitor=" .. tostring(mon or "?"))
    end
  else
    U.log("hyprwinwrap: plugin loaded but window() API missing")
  end
end

QM.features.hyprwinwrap = { class = CLASS, so = SO }
return QM.features.hyprwinwrap
