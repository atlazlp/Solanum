-- binds/apps.lua: application launchers (keybinds.conf "Apps" + hypr-user.conf extras). App launches keep app2unit.
local U, B = QM.util, QM.binds

hl.bind("SUPER + T", B.app("kitty"))                                   -- $terminal (hypr-vars.conf)
hl.bind("SUPER + W", B.app("firefox"))                                 -- $browser
hl.bind("SUPER + C", B.app("cursor -n"))                               -- $editor (was cursor-clean.sh = exec cursor -n)
hl.bind("SUPER + G", B.app("github-desktop"))
hl.bind("SUPER + E", B.app("bash " .. U.script("nautilus-wrap.sh")))  -- $fileExplorer
hl.bind("SUPER + ALT + E", B.app("nemo"))
hl.bind("CTRL + ALT + Escape", B.app("qps"))
hl.bind("CTRL + ALT + V", B.app("pavucontrol"))

-- hypr-user.conf personal tools
hl.bind("SUPER + SHIFT + A", B.exec("bash " .. U.script("activity-monitor.sh")))
hl.bind("SUPER + SHIFT + H", B.exec("bash " .. U.script("audio-toggle-analog-output.sh")))
hl.bind("SUPER + SHIFT + M", B.exec(U.qm_script("qm-random")))         -- clash resolved: qm-random only (no sink mute)
hl.bind("SUPER + SHIFT + C", B.exec("hyprpicker -a"))                  -- colour picker
hl.bind("SUPER + ALT + H", B.exec("bash " .. U.script("hearthstone-dc.sh")), { locked = true }) -- brief Hearthstone-only DC
