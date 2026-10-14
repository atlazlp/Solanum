-- binds/mouse.lua: side mouse buttons (hypr-user-local.conf 17-39).
--   hold mouse4 (275) + LMB drag = move, + RMB drag = resize
--   hold mouse5 (276) + LMB click = togglegroup / moveoutofgroup
-- Not while a Steam game is focused (hypr-mouse-submap-if-not-steam-game.sh). Release binds are matched
-- against the submap active at press, so the thumb release gets submap_universal to leave the submap.
local U = QM.util

local function steam_game_focused()
  local w = hl.get_active_window()
  return w ~= nil and U.starts_with(U.field(w, "class") or "", "steam_app_")
end

local function enter(submap)
  return function()
    if steam_game_focused() then return end
    hl.dispatch(hl.dsp.submap(submap))
  end
end

hl.bind("mouse:275", enter("mousedragthumb"))
hl.bind("mouse:275", hl.dsp.submap("reset"), { release = true, submap_universal = true })
hl.bind("mouse:276", enter("mouse5group"))
hl.bind("mouse:276", hl.dsp.submap("reset"), { release = true, submap_universal = true })

hl.define_submap("mousedragthumb", function()
  hl.bind("mouse:272", hl.dsp.window.drag(), { mouse = true })
  hl.bind("mouse:273", hl.dsp.window.resize(), { mouse = true })
  hl.bind("Escape", hl.dsp.submap("reset"))
end)

hl.define_submap("mouse5group", function()
  -- hypr-group-mouse5.sh: in a group -> move out of it, else toggle group
  hl.bind("mouse:272", function()
    local w = hl.get_active_window()
    if not w or steam_game_focused() then return end
    if U.field(w, "group") then
      hl.dispatch(hl.dsp.window.move({ out_of_group = true }))
    else
      hl.dispatch(hl.dsp.group.toggle())
    end
  end, { click = true })
  hl.bind("Escape", hl.dsp.submap("reset"))
end)
