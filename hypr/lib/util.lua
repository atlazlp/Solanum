-- lib/util.lua: paths, tiny fs helpers, timers, logging. Loaded first; hangs off the global QM table.
QM = QM or {}
local U = {}

U.HOME = os.getenv("HOME") or "/root"
U.RT = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
U.CFG = os.getenv("XDG_CONFIG_HOME") or (U.HOME .. "/.config")
U.STATE = (os.getenv("XDG_STATE_HOME") or (U.HOME .. "/.local/state")) .. "/solanum"
U.BIN = U.HOME .. "/.local/bin"

-- Directory this config lives in (the repo's hypr/ or ~/.config/hypr when symlinked).
local src = debug.getinfo(1, "S").source or ""
U.CFG_DIR = src:match("^@(.-)/lib/util%.lua$") or (U.CFG .. "/hypr")
U.SCRIPTS = U.CFG_DIR .. "/scripts"

function U.exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

function U.read_line(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local line = f:read("l")
  f:close()
  if not line then return nil end
  line = line:gsub("%s+$", "")
  if line == "" then return nil end
  return line
end

function U.read_all(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  return text
end

function U.write(path, text)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(text or "")
  f:close()
  return true
end

function U.touch(path) return U.write(path, "") end
function U.rm(path) os.remove(path) end

-- Quantum Moon engine root: ~/.config/caelestia/quantum-moon-root (Phase 1) or ~/.config/solanum/root,
-- else derived from the config dir (<repo>/hypr -> <repo>/solanum).
U.QM_ROOT = U.read_line(U.CFG .. "/caelestia/quantum-moon-root")
  or U.read_line(U.CFG .. "/solanum/root")
  or ((U.CFG_DIR:match("^(.*)/[^/]+$") or (U.HOME .. "/Projects/Quantum-Moon")) .. "/solanum")
U.REPO = U.QM_ROOT:match("^(.*)/[^/]+$") or U.QM_ROOT
U.QM_SCRIPTS = U.QM_ROOT .. "/scripts"

function U.script(name) return U.SCRIPTS .. "/" .. name end
function U.qm_script(name) return U.QM_SCRIPTS .. "/" .. name end

-- POSIX single-quote shell quoting.
function U.shq(s)
  local escaped = tostring(s):gsub("'", "'\\''")
  return "'" .. escaped .. "'"
end

function U.starts_with(s, prefix) return type(s) == "string" and s:sub(1, #prefix) == prefix end
function U.trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Safe field access on HL objects (expired handles throw).
function U.field(obj, name)
  local ok, v = pcall(function() return obj[name] end)
  if ok then return v end
  return nil
end

-- Vec2-like -> x, y (HL.Vec2 userdata, {x=,y=} or {x, y}).
-- VERIFY: window.size / monitor fields arrive as HL.Vec2 userdata with .x/.y (stubs); the [1]/[2] fallback is
-- pcall-guarded so an unexpected shape only turns the caller into a no-op.
function U.vec(v)
  if type(v) == "table" or type(v) == "userdata" then
    local ok, x, y = pcall(function() return v.x or v[1], v.y or v[2] end)
    if ok and x and y then return tonumber(x), tonumber(y) end
  end
  return nil, nil
end

-- Logical monitor size from the untransformed mode size (width/height), transform and scale
-- (same formula as main-monitor-hotplug.sh logical_width; m.size is not relied on).
function U.mon_size(m)
  local w, h = tonumber(U.field(m, "width")) or 0, tonumber(U.field(m, "height")) or 0
  local s = tonumber(U.field(m, "scale")) or 1
  if s <= 0 then s = 1 end
  local t = tonumber(U.field(m, "transform")) or 0
  if t % 2 == 1 then w, h = h, w end
  return math.floor(w / s + 0.5), math.floor(h / s + 0.5)
end

function U.is_game(w)
  local class = U.field(w, "class") or ""
  if U.starts_with(class, "steam_app_") or class == "gamescope" then return true end
  return U.field(w, "content_type") == "game"
end

function U.same_window(a, b)
  return a ~= nil and b ~= nil and U.field(a, "address") == U.field(b, "address")
end

-- Timers (never at load time: see hyprland.lua header).
function U.after(ms, fn) return hl.timer(fn, { timeout = ms, type = "oneshot" }) end
function U.every(ms, fn) return hl.timer(fn, { timeout = ms, type = "repeat" }) end

-- Trailing-edge debounce via a generation counter (a cancelled oneshot simply no-ops).
function U.debounce(ms, fn)
  local gen = 0
  return function(...)
    gen = gen + 1
    local mine = gen
    local args = table.pack(...)
    hl.timer(function()
      if mine == gen then fn(table.unpack(args, 1, args.n)) end
    end, { timeout = ms, type = "oneshot" })
  end
end

-- Run fn once the compositor is live: on first start and again after every reload (a reload wipes
-- timers and subscriptions, so repeat timers belong here). Under --verify-config hyprland.start never
-- fires and config.reloaded fires with zero monitors, so nothing runs there.
function U.on_live(fn)
  local done = false
  local function fire()
    if done then return end
    done = true
    local ok, err = pcall(fn)
    if not ok then U.log("on_live error: " .. tostring(err)) end
  end
  hl.on("hyprland.start", fire)
  hl.on("config.reloaded", function()
    if #hl.get_monitors() > 0 then fire() end
  end)
end

function U.log(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  local f = io.open(U.STATE .. "/hypr-lua.log", "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S "), table.concat(parts, " "), "\n")
    f:close()
  end
end

function U.notify(text, timeout)
  hl.notification.create({ text = text, timeout = timeout or 4000 })
end

-- Shell toast (info|warn|error) through lib/shell.lua.
function U.toast(kind, title, msg)
  local sh = QM.shell
  if not sh then return end
  hl.exec_cmd(sh.ipc("toaster", kind, U.shq(title), U.shq(msg), "''"))
end

QM.util = U
return U
