-- binds/init.lua: helpers shared by the bind modules, then the modules themselves.
-- Flag map from hyprlang: bind->{} binde->{repeating} bindl->{locked} bindle->{locked,repeating} bindr->{release}
-- bindm->drag/resize dispatcher + {mouse=true} bindc->{click} bindin->{ignore_mods,non_consuming}.
local B = {}

function B.exec(cmd, rules) return hl.dsp.exec_cmd(cmd, rules) end
function B.app(cmd) return hl.dsp.exec_cmd("app2unit -- " .. cmd) end
-- GlobalShortcut on whichever shell lib/shell.lua points at.
function B.global(name) return hl.dsp.global(QM.shell.global(name)) end

QM.binds = B

require("binds/apps")
require("binds/windows")
require("binds/workspaces")
require("binds/media")
require("binds/shell")
require("binds/mouse")

return B
