-- features/proton_ghosts.lua: close Proton/Steam ghost XWayland windows (Wine explorer /desktop, tiny
-- empty-title steam_app_* leaks) and kill the explorer.exe processes behind them (proton-hide-ghost-windows.sh).
local U = QM.util
local G = {}

local function steamish(class)
  return U.starts_with(class, "steam_app_") or class == "steam" or class == "steam_proton"
end

function G.is_ghost(w)
  local class = U.trim(U.field(w, "class") or "")
  if not steamish(class) then return false end
  if U.trim(U.field(w, "title") or "") ~= "" then return false end
  local x, y = U.vec(U.field(w, "size"))
  return x ~= nil and y ~= nil and y <= 30 and x <= 220
end

function G.sweep()
  for _, w in ipairs(hl.get_windows()) do
    if G.is_ghost(w) then
      hl.dispatch(hl.dsp.window.close({ window = w })) -- VERIFY: window= target (Config::Actions::closeWindow takes an optional window)
    end
  end
end

-- pgrep/readlink/kill loop, at most once per 1.5 s burst of steam window opens
local kill_explorer = U.debounce(1500, function()
  hl.exec_cmd("bash " .. U.script("qm-proton-kill-explorer"))
end)

hl.on("window.open", function(w)
  local class = U.field(w, "class") or ""
  if not steamish(class) then return end
  kill_explorer()
  U.after(300, function()
    if G.is_ghost(w) then hl.dispatch(hl.dsp.window.close({ window = w })) end
  end)
end)

-- Safety sweep (the script polled every second; 5 s is plenty with the open hook)
U.on_live(function() U.every(5000, G.sweep) end)

QM.features.proton_ghosts = G
return G
