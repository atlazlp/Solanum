-- features/launcher_super.lua: tap Super (alone, released within 400 ms) opens the launcher; any key or mouse
-- button while Super is held cancels it. Replaces super-launcher.sh + the 121 generated bindnitn interrupts.
--
-- Primary mechanism: hl.on("input.keyboard.key") sees every key (keycode = evdev + 8: KEY_LEFTMETA 125 -> 133,
-- KEY_RIGHTMETA 126 -> 134). VERIFY once live (hyprctl repl) that the event also fires for keys consumed by
-- binds (open risk in the plan). Until then `fallback_interrupts` keeps non-consuming SUPER+key interrupt binds
-- for the keys used by Super chords, exactly like hypr-launcher-interrupts.conf did.
local U, S = QM.util, QM.shell
local L = {
  tap_ms = 400,
  fallback_interrupts = true,
  down = false,
  interrupted = false,
  t0 = 0,
  code = nil,
}
local SUPER_CODES = { [133] = true, [134] = true }

local function interrupt()
  if L.down then L.interrupted = true end
end

function L.fire()
  hl.exec_cmd(S.launcher_toggle)
end

hl.on("input.keyboard.key", function(keycode, time_ms, state)
  if SUPER_CODES[keycode] then
    if state == 1 then
      if not L.down then
        L.down, L.interrupted, L.t0, L.code = true, false, time_ms, keycode
      end
    elseif L.down and L.code == keycode then
      local held = time_ms - L.t0
      local tap = not L.interrupted and held >= 0 and held <= L.tap_ms
      L.down = false
      if tap then L.fire() end
    end
  elseif state == 1 then
    interrupt()
  end
end)

-- Mouse interrupts (hypr-user.conf 22-29: bindin = Super, mouse:272..277 / mouse_up / mouse_down)
for _, key in ipairs({ "mouse:272", "mouse:273", "mouse:274", "mouse:275", "mouse:276", "mouse:277", "mouse_up", "mouse_down" }) do
  hl.bind("SUPER + " .. key, interrupt, { non_consuming = true, ignore_mods = true })
end

-- Keyboard interrupt fallback (bindnitn = Super, <key>): non-consuming, ignore mods, transparent.
if L.fallback_interrupts then
  for _, key in ipairs({
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "A", "C", "D", "E", "F", "G", "H", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Z",
    "Comma", "Period", "Minus", "Equal", "Space", "Backslash", "Tab", "Page_Up", "Page_Down",
    "left", "right", "up", "down",
  }) do
    hl.bind("SUPER + " .. key, interrupt, { non_consuming = true, ignore_mods = true, transparent = true })
  end
end

QM.features.launcher = L
return L
