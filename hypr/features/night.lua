-- features/night.lua: night light via hyprsunset, tinted per planet (scheme.night_temperature from
-- modes/<slug>/meta.json nightTemperature). Schedule 19:00-07:00 -> `hyprctl hyprsunset temperature N`,
-- otherwise `identity`. Re-evaluated every 60 s and on every reload (qm-apply reloads after a palette change).
-- The shell can override through ~/.local/state/solanum/nightlight.json {"enabled":bool,"temperature":N}
-- (written by `qs ... nightlight` in Phase 2); the file is re-read on every tick.
local U, S = QM.util, QM.scheme
local N = {
  enabled = true,
  temperature = S.night_temperature,
  start_hour = 19,
  end_hour = 7,
  last = nil,
}

local OVERRIDE = U.STATE .. "/nightlight.json"

local function read_override()
  local text = U.read_all(OVERRIDE)
  if not text then return end
  local enabled = text:match('"enabled"%s*:%s*(%a+)')
  local temp = text:match('"temperature"%s*:%s*(%d+)')
  if enabled then N.enabled = (enabled == "true") end
  if temp then N.temperature = tonumber(temp) end
end

function N.is_night()
  local hour = tonumber(os.date("%H")) or 12
  return hour >= N.start_hour or hour < N.end_hour
end

function N.apply(force)
  read_override()
  local want = (N.enabled and N.is_night()) and ("temperature " .. tostring(N.temperature)) or "identity"
  if want == N.last and not force then return end
  N.last = want
  -- no-op when hyprsunset is not installed/running (Phase 4 installs it)
  hl.exec_cmd("sh -c 'command -v hyprsunset >/dev/null 2>&1 && hyprctl hyprsunset " .. want .. " >/dev/null 2>&1'")
end

U.on_live(function()
  N.apply(true)
  U.every(60000, function() N.apply(false) end)
end)

QM.features.night = N
return N
