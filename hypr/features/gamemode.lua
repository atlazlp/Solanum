-- features/gamemode.lua: game mode = a game window (steam_app_*, gamescope, content_type "game") is visible
-- or fullscreen. Enter: touch $XDG_RUNTIME_DIR/quantum-moon-game-mode.active, pause mpvpaper (qm-mpv-ipc),
-- tell the shell. Exit: reverse. Debounced 300 ms on window/workspace events + 5 s safety poll.
-- Phase 1 note: the Caelestia shell's own GameMode (game-mode-resources.sh, caelestia-game-mode.active) runs
-- alongside; qm-video-watch honours both marker names.
local U, S = QM.util, QM.shell
local G = { active = false }

local MARKER = U.RT .. "/quantum-moon-game-mode.active"

local function game_visible()
  for _, w in ipairs(hl.get_windows()) do
    if U.is_game(w) then
      local visible = U.field(w, "visible")
      local fullscreen = (tonumber(U.field(w, "fullscreen")) or 0) > 0
      if visible or fullscreen then return true end
    end
  end
  return false
end

function G.set(on)
  if on == G.active then return end
  G.active = on
  if on then
    U.touch(MARKER)
    hl.exec_cmd(U.script("qm-mpv-ipc") .. " pause true")
  else
    U.rm(MARKER)
    hl.exec_cmd(U.script("qm-mpv-ipc") .. " pause false")
  end
  hl.exec_cmd(S.game_mode(on))
  U.log("gamemode:", on and "on" or "off")
end

G.check = U.debounce(300, function() G.set(game_visible()) end)

for _, ev in ipairs({
  "window.open", "window.close", "window.fullscreen", "window.class", "window.move_to_workspace",
  "workspace.active", "workspace.special_active", "monitor.focused",
}) do
  hl.on(ev, function() G.check() end)
end

U.on_live(function()
  G.active = U.exists(MARKER) -- survive reloads without re-sending IPC
  G.check()
  U.every(5000, function() G.check() end)
end)

QM.features.gamemode = G
return G
