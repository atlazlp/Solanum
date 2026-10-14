-- features/hotplug.lua: keep the bar/video on the preferred main monitor (DP-2). When it disappears, pack the
-- remaining outputs left-to-right at y=0 and promote the rightmost one; when it returns, re-apply the default
-- layout. Port of main-monitor-hotplug.sh (debounce 800 ms, marker in STATE, toast, qm-apply --persisted).
local U, M, S = QM.util, QM.monitors, QM.shell
local H = {}

local MARKER = U.STATE .. "/main-monitor-fallback"
H.preferred = function() return M.preferred_main end

local function monitors()
  local list = {}
  for _, m in ipairs(hl.get_monitors()) do
    if U.field(m, "name") then list[#list + 1] = m end
  end
  return list
end

local function find(name)
  for _, m in ipairs(monitors()) do
    if U.field(m, "name") == name then return m end
  end
  return nil
end

local function sorted()
  local list = monitors()
  table.sort(list, function(a, b)
    local ax, bx = tonumber(U.field(a, "x")) or 0, tonumber(U.field(b, "x")) or 0
    if ax ~= bx then return ax < bx end
    return (tonumber(U.field(a, "y")) or 0) < (tonumber(U.field(b, "y")) or 0)
  end)
  return list
end

local function logical_width(m)
  local lw = U.mon_size(m)
  return lw
end

local function adjacent(list)
  for i = 2, #list do
    local prev = list[i - 1]
    local expected = (tonumber(U.field(prev, "x")) or 0) + logical_width(prev)
    if math.abs((tonumber(U.field(list[i], "x")) or 0) - expected) > 2 then return false end
  end
  return true
end

local function fmt_refresh(r)
  r = tonumber(r) or 60
  if r == math.floor(r) then return string.format("%d", r) end
  return string.format("%.2f", r)
end

local function fmt_scale(s)
  s = tonumber(s) or 1
  if s <= 0 then s = 1 end
  if s == math.floor(s) then return string.format("%d", s) end
  return tostring(s)
end

-- Re-spec every connected monitor left-to-right at y=0 (hl.monitor merges fields and refreshes).
local function pack(list)
  local x = 0
  for _, m in ipairs(list) do
    local spec = {
      output = U.field(m, "name"),
      mode = string.format("%dx%d@%s", tonumber(U.field(m, "width")) or 0, tonumber(U.field(m, "height")) or 0, fmt_refresh(U.field(m, "refresh_rate"))),
      position = string.format("%dx0", x),
      scale = fmt_scale(U.field(m, "scale")),
    }
    local t = tonumber(U.field(m, "transform")) or 0
    if t ~= 0 then spec.transform = t end
    hl.monitor(spec)
    U.log("hotplug: place", spec.output, "at", spec.position)
    x = x + logical_width(m)
  end
end

-- Phase 1 only: the Caelestia bar follows shell.json bar.excludedScreens (main-monitor-hotplug.sh set_bar_host).
local function set_caelestia_bar_host(host, list)
  local shell_json = U.CFG .. "/caelestia/shell.json"
  if not U.exists(shell_json) then return end
  local excluded = {}
  for _, m in ipairs(list) do
    local name = U.field(m, "name")
    if name ~= host then excluded[#excluded + 1] = string.format("%q", name) end
  end
  local json = "[" .. table.concat(excluded, ",") .. "]"
  -- hl.exec_cmd already runs through `sh -c`, so the pipeline is passed as-is.
  hl.exec_cmd(string.format(
    [[tmp=$(mktemp %s.tmp.XXXXXX) && jq --argjson ex %s '.bar.excludedScreens = $ex' %s > "$tmp" && install -m644 "$tmp" %s; rm -f "$tmp"]],
    U.shq(shell_json), U.shq(json), U.shq(shell_json), U.shq(shell_json)))
end

local function announce(host, msg, list)
  hl.exec_cmd(S.monitors_hotplug(host))
  set_caelestia_bar_host(host, list)
  hl.dispatch(hl.dsp.focus({ monitor = host }))
  hl.exec_cmd(U.qm_script("qm-apply") .. " --persisted")
  U.toast("info", "Monitors", msg)
  U.log("hotplug:", msg)
end

function H.apply()
  local was_fallback = U.exists(MARKER)
  local list = sorted()
  if #list == 0 then return end

  if find(M.preferred_main) then
    if was_fallback then
      M.apply_default()
      U.rm(MARKER)
      U.after(400, function() announce(M.preferred_main, "Main monitor restored (" .. M.preferred_main .. ")", sorted()) end)
    end
    return
  end

  local host = U.field(list[#list], "name")
  if not adjacent(list) then pack(list) end
  U.write(MARKER, "bar_host=" .. host .. "\n")
  if not was_fallback then
    U.after(400, function() announce(host, "Main -> " .. host .. " (bar moved)", sorted()) end)
  end
end

local schedule = U.debounce(800, H.apply)
hl.on("monitor.added", function() schedule() end)
hl.on("monitor.removed", function() schedule() end)
-- Reconcile shortly after start/reload (the script ran apply() once at start and every 6 s in fallback).
U.on_live(function()
  U.after(1500, H.apply)
  U.every(6000, function() if U.exists(MARKER) then H.apply() end end)
end)

QM.features.hotplug = H
return H
