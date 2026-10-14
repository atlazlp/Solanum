-- features/pip.lua: picture-in-picture windows -> float, 25% of the monitor width keeping aspect, bottom-right,
-- pinned. Replaces `caelestia resizer -d` + `caelestia resizer pip` (Super+Alt+Backslash).
-- rules.lua already floats/pins/positions PiP windows on open; this adds the resize.
local U = QM.util
local P = {}

local PATTERN = "Picture[%- ]in[%- ][Pp]icture"

function P.is_pip(w)
  local title = U.field(w, "title") or ""
  return title:find(PATTERN) ~= nil
end

function P.place(w)
  local m = U.field(w, "monitor") or hl.get_active_monitor()
  if not m then return end
  local mw, mh = U.mon_size(m)
  local wx, wy = U.vec(U.field(w, "size"))
  if not wx or wx <= 0 or not wy or wy <= 0 then return end

  local width = math.floor(mw * 0.25 + 0.5)
  local height = math.floor(width * wy / wx + 0.5)
  local mx, my = tonumber(U.field(m, "x")) or 0, tonumber(U.field(m, "y")) or 0
  local x = mx + mw - width - math.floor(mw * 0.02)
  local y = my + mh - height - math.floor(mh * 0.03)

  if not U.field(w, "floating") then
    hl.dispatch(hl.dsp.window.float({ action = "set", window = w })) -- VERIFY: window= target
  end
  hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = w }))
  hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = w }))
  if not U.field(w, "pinned") then
    hl.dispatch(hl.dsp.window.pin({ window = w }))
  end
end

-- On open/title change act only when the PiP window is the active one, so an unverified `window=` key can
-- never resize the wrong window (the window rule still floats/pins/positions it).
local function on_window(w)
  if not P.is_pip(w) then return end
  U.after(150, function()
    if U.same_window(hl.get_active_window(), w) then P.place(w) end
  end)
end

hl.on("window.open", on_window)
hl.on("window.title", on_window)

-- Super+Alt+Backslash: make the focused window a PiP window
hl.bind("SUPER + ALT + Backslash", function()
  local w = hl.get_active_window()
  if w then P.place(w) end
end)

QM.features.pip = P
return P
