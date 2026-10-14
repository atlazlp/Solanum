-- binds/windows.lua: window groups, focus/move/resize, mouse drags, pin/fullscreen/float/close (keybinds.conf 107-145).
-- Alt+Tab cycling lives in features/alttab.lua, PiP in features/pip.lua, scratchpad in features/special.lua.
local U = QM.util

-- Window groups
hl.bind("CTRL + ALT + Tab", hl.dsp.group.next(), { repeating = true })          -- changegroupactive f
hl.bind("CTRL + SHIFT + ALT + Tab", hl.dsp.group.prev(), { repeating = true })  -- changegroupactive b
hl.bind("SUPER + Comma", hl.dsp.group.toggle())                                  -- togglegroup
hl.bind("SUPER + U", hl.dsp.window.move({ out_of_group = true }))               -- moveoutofgroup
hl.bind("SUPER + SHIFT + Comma", hl.dsp.group.lock_active({ action = "toggle" })) -- lockactivegroup toggle

-- Focus / move
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  hl.bind("SUPER + " .. dir, hl.dsp.focus({ direction = dir }))
  hl.bind("SUPER + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end

-- resizeactive with % (relative to the window's own size) -> computed in Lua
local function resize_pct(fx, fy)
  return function()
    local w = hl.get_active_window()
    if not w then return end
    local sx, sy = U.vec(U.field(w, "size"))
    if not sx then return end
    hl.dispatch(hl.dsp.window.resize({
      x = math.floor(sx * fx + 0.5),
      y = math.floor(sy * fy + 0.5),
      relative = true,
    }))
  end
end

hl.bind("SUPER + Minus", resize_pct(-0.10, 0), { repeating = true })
hl.bind("SUPER + Equal", resize_pct(0.10, 0), { repeating = true })
hl.bind("SUPER + SHIFT + Minus", resize_pct(0, -0.10), { repeating = true })
hl.bind("SUPER + SHIFT + Equal", resize_pct(0, 0.10), { repeating = true })
hl.bind("SUPER + ALT + left", resize_pct(-0.10, 0), { repeating = true })
hl.bind("SUPER + ALT + right", resize_pct(0.10, 0), { repeating = true })
hl.bind("SUPER + ALT + up", resize_pct(0, -0.10), { repeating = true })
hl.bind("SUPER + ALT + down", resize_pct(0, 0.10), { repeating = true })

-- bindm: drag / resize with the mouse
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + Z", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("SUPER + X", hl.dsp.window.resize(), { mouse = true })

-- centerwindow 1 (respect reserved area)
hl.bind("CTRL + SUPER + Backslash", hl.dsp.window.center({ respect_reserved = true })) -- VERIFY: option key for "centerwindow 1"

-- resizeactive exact 55% 70% (of the monitor) + centerwindow 1
hl.bind("CTRL + SUPER + ALT + Backslash", function()
  local w = hl.get_active_window()
  if not w then return end
  local m = U.field(w, "monitor") or hl.get_active_monitor()
  if not m then return end
  local mw, mh = U.mon_size(m)
  hl.dispatch(hl.dsp.window.resize({ x = math.floor(mw * 0.55), y = math.floor(mh * 0.70) }))
  hl.dispatch(hl.dsp.window.center({ respect_reserved = true }))
end)

hl.bind("SUPER + P", hl.dsp.window.pin())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })) -- fullscreen 1
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + Q", hl.dsp.window.close())
