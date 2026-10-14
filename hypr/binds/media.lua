-- binds/media.lua: volume (wpctl), media and brightness globals (keybinds.conf 19-31, 172-177).
-- Ctrl+Super+Space (mediaToggle) is gone: it is the scratchpad toggle only (features/special.lua).
-- Super+Shift+M (sink mute) is gone: it is qm-random only (binds/apps.lua).
local B = QM.binds
local L = { locked = true }
local LR = { locked = true, repeating = true }

-- Volume
hl.bind("XF86AudioMicMute", B.exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), L)
hl.bind("XF86AudioMute", B.exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), L)
hl.bind("XF86AudioRaiseVolume", B.exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+"), LR)
hl.bind("XF86AudioLowerVolume", B.exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-"), LR)

-- Media (shell GlobalShortcuts)
hl.bind("XF86AudioPlay", B.global("mediaToggle"), L)
hl.bind("XF86AudioPause", B.global("mediaToggle"), L)
hl.bind("CTRL + SUPER + Equal", B.global("mediaNext"), L)
hl.bind("XF86AudioNext", B.global("mediaNext"), L)
hl.bind("CTRL + SUPER + Minus", B.global("mediaPrev"), L)
hl.bind("XF86AudioPrev", B.global("mediaPrev"), L)
hl.bind("XF86AudioStop", B.global("mediaStop"), L)

-- Brightness
hl.bind("XF86MonBrightnessUp", B.global("brightnessUp"), L)
hl.bind("XF86MonBrightnessDown", B.global("brightnessDown"), L)
