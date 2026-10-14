-- features/special.lua: special-workspace helpers that replace caelestia-cli `toggle` and toggle-special-window.sh.
--   toggle_window()   scratchpad: move the focused window into special:special, or back to the monitor's
--                     active workspace (silent), toggling visibility (toggle-special-window.sh).
--   toggle_specialws() `caelestia toggle specialws`: toggle the special workspace open on the focused monitor,
--                     else "special".
--   toggle_app(name, opts) `caelestia toggle <name>`: spawn opts.launch on special:<name> when no window matches
--                     opts.match, optionally move matching windows there, else toggle the special workspace.
local U = QM.util
local P = {}

local TARGET = "special:special"

local function open_special_name(m)
  local ws = U.field(m, "active_special_workspace")
  return ws and U.field(ws, "name") or nil
end

local function short(name) return (name:gsub("^special:", "")) end

function P.toggle_window()
  local w = hl.get_active_window()
  if not w then return end
  local m = U.field(w, "monitor") or hl.get_active_monitor()
  if not m then return end
  local ws = U.field(w, "workspace")
  local ws_name = ws and U.field(ws, "name") or ""

  if U.starts_with(ws_name, "special:") then
    local active = U.field(m, "active_workspace")
    local name = active and U.field(active, "name") or "1"
    hl.dispatch(hl.dsp.window.move({ workspace = "name:" .. name, follow = false })) -- movetoworkspacesilent
    local open = open_special_name(m)
    if open then hl.dispatch(hl.dsp.workspace.toggle_special(short(open))) end
  else
    hl.dispatch(hl.dsp.window.move({ workspace = TARGET, follow = false }))
    if open_special_name(m) ~= TARGET then hl.dispatch(hl.dsp.workspace.toggle_special(short(TARGET))) end
  end
end

function P.toggle_specialws()
  local m = hl.get_active_monitor()
  local open = m and open_special_name(m)
  hl.dispatch(hl.dsp.workspace.toggle_special(open and short(open) or "special"))
end

function P.toggle_app(name, opts)
  opts = opts or {}
  local special = "special:" .. name
  local matches = {}
  if opts.match then
    for _, w in ipairs(hl.get_windows()) do
      if opts.match(w) then matches[#matches + 1] = w end
    end
  end

  local spawned = false
  if opts.launch and #matches == 0 then
    -- caelestia-cli: hyprctl dispatch exec "[workspace special:<name>] app2unit -- <cmd>"
    hl.exec_cmd("app2unit -- " .. opts.launch, { workspace = special }) -- VERIFY: exec-rule key name
    spawned = true
  end

  if opts.move then
    for _, w in ipairs(matches) do
      local ws = U.field(w, "workspace")
      if not ws or U.field(ws, "name") ~= special then
        hl.dispatch(hl.dsp.window.move({ workspace = special, follow = false, window = w })) -- VERIFY: window= target
      end
    end
  end

  if not spawned then hl.dispatch(hl.dsp.workspace.toggle_special(name)) end
end

local function class_is(name)
  return function(w) return U.field(w, "class") == name end
end

-- Special workspace toggles (keybinds.conf 147-151; Super+D is the window picker, see binds/shell.lua)
hl.bind("CTRL + SHIFT + Escape", function()
  P.toggle_app("sysmon", { match = class_is("btop"), launch = "kitty --class btop --title btop -e btop" })
end)
hl.bind("SUPER + M", function() hl.dispatch(hl.dsp.workspace.toggle_special("music")) end)
hl.bind("SUPER + R", function()
  P.toggle_app("todo", { match = class_is("Todoist"), launch = "todoist", move = true })
end)

-- Toggle special workspace (keybinds.conf:71)
hl.bind("SUPER + S", P.toggle_specialws)

-- special:special scratchpad: move the focused window in/out (hypr-user.conf 65-70).
-- Ctrl+Super+Space is the scratchpad toggle only (the caelestia mediaToggle on it was dropped).
hl.bind("SUPER + ALT + S", P.toggle_window)
hl.bind("CTRL + SUPER + S", P.toggle_window)
hl.bind("CTRL + SUPER + Space", P.toggle_window)

QM.special = P
QM.features.special = P
return P
