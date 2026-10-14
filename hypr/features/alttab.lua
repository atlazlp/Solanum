-- features/alttab.lua: Alt+Tab / Shift+Alt+Tab cycling over all mapped windows sorted by their display line
-- (port of window_menu.py `cycle` + hypr-focus-window.sh group-tab focus).
local U = QM.util
local A = {}

local function split(s, sep)
  local out, pos = {}, 1
  while true do
    local i, j = s:find(sep, pos, true)
    if not i then
      out[#out + 1] = s:sub(pos)
      break
    end
    out[#out + 1] = s:sub(pos, i - 1)
    pos = j + 1
  end
  return out
end

local function cap_class(s)
  s = U.trim(s)
  if s == "" then return "?" end
  if #s > 1 then return s:sub(1, 1):upper() .. s:sub(2):lower() end
  return s:upper()
end

local function norm(s)
  s = tostring(s or "")
  s = s:gsub(" — ", " - ")
  s = s:gsub("—", " - ")
  s = s:gsub(" – ", " - ")
  return U.trim(s)
end

local function parts_from_title(title)
  local parts = {}
  for _, p in ipairs(split(norm(title), " - ")) do
    p = U.trim(p)
    if p ~= "" then parts[#parts + 1] = p end
  end
  return parts
end

local function pop_trailing_app(parts, class, initial_class)
  local k = (class or ""):lower()
  local ic = (initial_class or ""):lower()
  while #parts > 0 do
    local last = parts[#parts]:lower():gsub("%.+$", "")
    if k == "firefox" and (U.starts_with(last, "mozilla fi") or last:find("mozilla firefox", 1, true)) then
      table.remove(parts)
    elseif last == k then
      table.remove(parts)
    elseif ic ~= "" and last == ic then
      table.remove(parts)
    else
      break
    end
  end
  return parts
end

local function invert(parts)
  if #parts <= 1 then return parts end
  local out = {}
  for i = #parts, 1, -1 do out[#out + 1] = parts[i] end
  return out
end

function A.display_line(class, initial_class, title)
  local parts = invert(pop_trailing_app(parts_from_title(title), class, initial_class))
  local head = cap_class(class)
  if #parts > 0 then return head .. " - " .. table.concat(parts, " - ") end
  return head
end

-- Mapped, non-hidden windows sorted by display line (case-insensitive), address as tiebreaker.
function A.rows()
  local rows = {}
  for _, w in ipairs(hl.get_windows()) do
    if not U.field(w, "hidden") and U.field(w, "address") then
      rows[#rows + 1] = {
        window = w,
        address = U.field(w, "address"),
        line = A.display_line(U.field(w, "class") or "", U.field(w, "initial_class") or "", U.field(w, "title") or ""),
      }
    end
  end
  table.sort(rows, function(a, b)
    local la, lb = a.line:lower(), b.line:lower()
    if la ~= lb then return la < lb end
    return a.address < b.address
  end)
  return rows
end

-- Focus a window, including the right tab when it is hidden inside a group (hypr-focus-window.sh).
function A.focus(w)
  hl.dispatch(hl.dsp.focus({ window = w }))
  local group = U.field(w, "group")
  if not group then return end
  local size = tonumber(U.field(group, "size")) or 0
  if size < 2 then return end
  local tries = 0
  local function step()
    if U.same_window(hl.get_active_window(), w) then return end
    if tries == 0 then
      local head = U.field(group, "current")
      if head then hl.dispatch(hl.dsp.focus({ window = head })) end
    else
      hl.dispatch(hl.dsp.group.next())
    end
    tries = tries + 1
    if tries <= size then U.after(30, step) end
  end
  U.after(80, step)
end

function A.cycle(direction)
  local rows = A.rows()
  if #rows == 0 then return end
  local active = hl.get_active_window()
  local addr = active and U.field(active, "address")
  local idx
  for i, r in ipairs(rows) do
    if r.address == addr then idx = i break end
  end
  local target
  if idx then
    if direction == "prev" then
      target = rows[((idx - 2) % #rows) + 1]
    else
      target = rows[(idx % #rows) + 1]
    end
  else
    target = rows[1]
  end
  A.focus(target.window)
end

hl.bind("ALT + Tab", function() A.cycle("next") end, { repeating = true })
hl.bind("SHIFT + ALT + Tab", function() A.cycle("prev") end, { repeating = true })

QM.features.alttab = A
return A
