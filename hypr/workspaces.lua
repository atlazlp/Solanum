-- workspaces.lua: workspace rules (rules.conf:93-94 with $singleWindowGapsOut = $windowGapsOut from hypr-vars.conf)
-- and the workspace-group arithmetic from scripts/wsaction.fish.
hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = 10 })
hl.workspace_rule({ workspace = "f[1]s[false]", gaps_out = 10 })

local W = {}

function W.active_id()
  local ws = hl.get_active_workspace()
  local id = ws and tonumber(ws.id) or 1
  if id < 1 then id = 1 end -- special workspaces have negative ids
  return id
end

-- wsaction.fish: workspace n of the current group  -> floor((a-1)/10)*10 + n
function W.in_group(n)
  local a = W.active_id()
  return math.floor((a - 1) / 10) * 10 + n
end

-- wsaction.fish -g: same slot in group n -> (n-1)*10 + a%10  (slot 10 maps to n*10 instead of workspace 0)
function W.group(n)
  local a = W.active_id()
  local slot = a % 10
  if slot == 0 then slot = 10 end
  return (n - 1) * 10 + slot
end

QM.ws = W
return W
