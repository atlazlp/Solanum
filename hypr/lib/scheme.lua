-- lib/scheme.lua: colours for borders/groupbar/shadow/background + per-planet night temperature.
-- qm-apply writes ~/.local/state/solanum/scheme.lua atomically and runs `hyprctl reload`.
-- Loaded with dofile (NOT require) so the state file is not added to the inotify reload set.
local U = QM.util
local PATH = U.STATE .. "/scheme.lua"

local S
local ok, data = pcall(dofile, PATH)
if ok and type(data) == "table" and type(data.colours) == "table" then
  S = data
  S.source = PATH
else
  S = require("lib/scheme-default")
  S.source = "lib/scheme-default.lua"
end

S.colours = S.colours or {}
S.groupbar = S.groupbar or {}
S.slug = S.slug or "unknown"
S.night_temperature = tonumber(S.night_temperature) or 4500
S.shadow_tint = S.shadow_tint or S.colours.shadow or "000000"

function S.hex(key, fallback)
  return S.colours[key] or fallback or "ff00ff"
end

function S.rgb(key, fallback)
  return "rgb(" .. S.hex(key, fallback) .. ")"
end

function S.rgba(key, alpha, fallback)
  return "rgba(" .. S.hex(key, fallback) .. (alpha or "ff") .. ")"
end

-- groupbar role (active_bg, inactive_fg, ...) -> colour key, with a fallback key.
function S.gb(role, fallback_key)
  return S.groupbar[role] or fallback_key
end

QM.scheme = S
return S
