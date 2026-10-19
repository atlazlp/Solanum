-- features/gamemode.lua: manual game mode only.
-- Enable/disable is owned by the shell Status glyph (GameMode.qml → game-mode-resources.sh).
-- Auto-detect of steam_app_*/gamescope windows is intentionally disabled.
local U = QM.util
local G = { active = false }

local MARKER = U.RT .. "/solanum-game-mode.active"

function G.set(on)
  if on == G.active then return end
  G.active = on
  if on then
    U.touch(MARKER)
  else
    U.rm(MARKER)
  end
  U.log("gamemode:", on and "on" or "off", "(manual)")
end

U.on_live(function()
  G.active = U.exists(MARKER)
  U.every(5000, function()
    G.active = U.exists(MARKER)
  end)
end)

QM.features.gamemode = G
return G
