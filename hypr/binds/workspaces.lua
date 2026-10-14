-- binds/workspaces.lua: workspace navigation and window-to-workspace moves (keybinds.conf 37-105 + hypr-user.conf).
-- Group arithmetic comes from QM.ws (workspaces.lua). Scratchpad/special toggles live in features/special.lua.
local W = QM.ws

-- Go to workspace # / workspace group #, move window to workspace # / group #
for i = 1, 10 do
  local key = i % 10 -- 10 -> key 0
  hl.bind("SUPER + " .. key, function() hl.dispatch(hl.dsp.focus({ workspace = tostring(W.in_group(i)) })) end)
  hl.bind("CTRL + SUPER + " .. key, function() hl.dispatch(hl.dsp.focus({ workspace = tostring(W.group(i)) })) end)
  hl.bind("SUPER + ALT + " .. key, function() hl.dispatch(hl.dsp.window.move({ workspace = tostring(W.in_group(i)) })) end)
  hl.bind("CTRL + SUPER + ALT + " .. key, function() hl.dispatch(hl.dsp.window.move({ workspace = tostring(W.group(i)) })) end)
end

-- Go to workspace -1/+1 (relative ids, like `workspace, -1`)
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "-1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "+1" }))
hl.bind("CTRL + SUPER + left", hl.dsp.focus({ workspace = "-1" }), { repeating = true })
hl.bind("CTRL + SUPER + right", hl.dsp.focus({ workspace = "+1" }), { repeating = true })
hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "-1" }), { repeating = true })
hl.bind("SUPER + Page_Down", hl.dsp.focus({ workspace = "+1" }), { repeating = true })
-- Go to workspace group -1/+1
hl.bind("CTRL + SUPER + mouse_down", hl.dsp.focus({ workspace = "-10" }))
hl.bind("CTRL + SUPER + mouse_up", hl.dsp.focus({ workspace = "+10" }))

-- Move window to workspace -1/+1
hl.bind("SUPER + ALT + Page_Up", hl.dsp.window.move({ workspace = "-1" }), { repeating = true })
hl.bind("SUPER + ALT + Page_Down", hl.dsp.window.move({ workspace = "+1" }), { repeating = true })
hl.bind("SUPER + ALT + mouse_down", hl.dsp.window.move({ workspace = "-1" }))
hl.bind("SUPER + ALT + mouse_up", hl.dsp.window.move({ workspace = "+1" }))
hl.bind("CTRL + SUPER + SHIFT + right", hl.dsp.window.move({ workspace = "+1" }), { repeating = true })
hl.bind("CTRL + SUPER + SHIFT + left", hl.dsp.window.move({ workspace = "-1" }), { repeating = true })
-- Bring window back from a special workspace to the current one (movetoworkspace e+0).
-- (Ctrl+Super+Shift+Up and Super+Alt+S were unbound by hypr-user.conf in favour of the scratchpad toggle.)
hl.bind("CTRL + SUPER + SHIFT + down", hl.dsp.window.move({ workspace = "e+0" }))
