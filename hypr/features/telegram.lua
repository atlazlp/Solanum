-- features/telegram.lua: when the Telegram media viewer closes (or any Telegram window leaves fullscreen) the
-- chat window can stay stuck fullscreen; clear it 80 ms later (telegram-unfullscreen-chat.py).
local U = QM.util
local T = {}

local CLASS = "org.telegram.desktop"

function T.clear()
  for _, w in ipairs(hl.get_windows({ class = CLASS })) do
    local stuck = (tonumber(U.field(w, "fullscreen")) or 0) > 0 or (tonumber(U.field(w, "fullscreen_client")) or 0) > 0
    if stuck and U.field(w, "title") ~= "Media viewer" then
      hl.dispatch(hl.dsp.focus({ window = w }))
      hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = w }))
    end
  end
end

local function schedule() U.after(80, T.clear) end

-- The script reacted to every closewindow and to fullscreen>>0 (any window); keep that but skip the cheap
-- class check when the handle already expired.
hl.on("window.close", function(w)
  local class = U.field(w, "class")
  if class == nil or class == CLASS then schedule() end
end)
hl.on("window.fullscreen", function(w)
  if (tonumber(U.field(w, "fullscreen")) or 0) == 0 then schedule() end
end)

QM.features.telegram = T
return T
