-- rules.lua: window + layer rules. Final intent of caelestia hyprland/rules.conf + ~/.config/caelestia/hypr-user.conf
-- (Discord/Spotify tiled instead of special-workspace routed, Telegram media viewer barred, Proton ghosts no_focus).
-- Regex backslashes are doubled; "negative:" negates; % size/move shorthands are muParser expressions.
local rule = hl.window_rule
local layer = hl.layer_rule

-- ######## Window rules ########
rule({ name = "opacity-non-fullscreen", match = { fullscreen = false }, opacity = "0.95 override" })

-- Native transparency or we want them opaque
rule({ name = "opaque-natives", match = { class = "foot|equibop|org\\.quickshell|imv|swappy" }, opaque = true })
-- Center all floating windows (not xwayland cause popups)
rule({ name = "center-floating", match = { float = true, xwayland = false }, center = true })

-- Float
for _, class in ipairs({
  "guifetch", "yad", "zenity", "wev", "org\\.gnome\\.FileRoller", "file-roller", "blueman-manager",
  "com\\.github\\.GradienceTeam\\.Gradience", "feh", "imv", "system-config-printer", "org\\.quickshell",
}) do
  rule({ name = "float-" .. class:gsub("[^%w]", "_"), match = { class = class }, float = true })
end

-- Float, resize and center
rule({ name = "nmtui", match = { class = "foot", title = "nmtui" }, float = true, size = { "monitor_w*0.6", "monitor_h*0.7" }, center = true })
rule({ name = "gnome-settings", match = { class = "org\\.gnome\\.Settings" }, float = true, size = { "monitor_w*0.7", "monitor_h*0.8" }, center = true })
rule({ name = "pavucontrol", match = { class = "org\\.pulseaudio\\.pavucontrol|yad-icon-browser" }, float = true, size = { "monitor_w*0.6", "monitor_h*0.7" }, center = true })
rule({ name = "nwg-look", match = { class = "nwg-look" }, float = true, size = { "monitor_w*0.5", "monitor_h*0.6" }, center = true })

-- Special workspaces (Spotify and Discord deliberately NOT routed: they tile on the active workspace)
rule({ name = "special-sysmon", match = { class = "btop" }, workspace = "special:sysmon" })
rule({ name = "special-music", match = { class = "feishin|Supersonic|Cider|com.github.th_ch.youtube_music|Plexamp|com-maxrave-simpmusic-MainKt" }, workspace = "special:music" })
rule({ name = "special-communication", match = { class = "equibop|vesktop|whatsapp" }, workspace = "special:communication" })
rule({ name = "special-todo", match = { class = "Todoist" }, workspace = "special:todo" })

-- Dialogs
for i, title in ipairs({
  "(Select|Open)( a)? (File|Folder)(s)?",
  "File (Operation|Upload)( Progress)?",
  ".* Properties",
  "Export Image as PNG",
  "GIMP Crash Debug",
  "Save As",
  "Library",
}) do
  rule({ name = "float-dialog-" .. i, match = { title = title }, float = true })
end

-- Picture in picture (initial placement bottom-right; features/pip.lua does the resize)
local PIP = "Picture(-| )in(-| )[Pp]icture"
rule({
  name = "pip",
  match = { title = PIP },
  float = true,
  pin = true,
  keep_aspect_ratio = true,
  move = { "monitor_w-window_w-monitor_w*0.02", "monitor_h-window_h-monitor_h*0.03" },
})

-- Creative software
rule({ name = "opaque-creative", match = { class = "krita|gimp|inkscape|darktable|resolve|kdenlive|shotcut|blender|godot" }, opaque = true })

-- Godot solar-system wallpaper (hyprwinwrap class must match exactly: qm-solar-wallpaper)
rule({
  name = "qm-solar-wallpaper",
  match = { class = "qm-solar-wallpaper" },
  float = true,
  pin = true,
  no_focus = true,
  no_anim = true,
  border_size = 0,
  rounding = 0,
  opacity = "1.0 override 1.0 override",
  opaque = true,
})

-- Ueberzugpp
rule({ name = "ueberzugpp", match = { class = "^(ueberzugpp_.*)$" }, float = true, no_initial_focus = true })

-- Steam
rule({ name = "steam-rounding", match = { class = "steam" }, rounding = 10 })
rule({ name = "steam-friends", match = { class = "steam", title = "Friends List" }, float = true })

-- Games (Steam, Lutris/Wine, Gamescope): opaque, tearing allowed, always idle-inhibit
rule({ name = "games", match = { class = "(steam_app_(default|[0-9]+))|gamescope" }, opaque = true, immediate = true, idle_inhibit = "always" })

-- Proton/Steam: tiny floating ghost windows (explorer /desktop, CEF leaks) must not steal focus
rule({ name = "proton-ghosts", match = { class = "steam_app_.*", float = true, initial_title = "negative:.+" }, no_focus = true, no_initial_focus = true })

-- Waydroid: Android framebuffer is fixed, live resize clips; lock the window to that size
rule({ name = "waydroid", match = { class = "^(waydroid|Waydroid)$" }, float = true, size = { 1920, 1080 }, center = true, opaque = true, idle_inhibit = "always" })

-- Minecraft launcher consoles
rule({ name = "atlauncher-console", match = { class = "com-atlauncher-App", title = "ATLauncher Console" }, float = true })
rule({ name = "pandora-console", match = { class = "PandoraLauncher", title = "Minecraft Game Output" }, float = true })

-- Autodesk Fusion 360
rule({ name = "fusion360", match = { class = "fusion360\\.exe", title = "Fusion360|(Marking Menu)" }, no_blur = true })

-- Ugh xwayland popups
rule({ name = "xwayland-popups", match = { xwayland = true, title = "win[0-9]+" }, no_dim = true, no_shadow = true, rounding = 10 })

-- Discord: tiled on the active workspace
rule({ name = "discord", match = { class = "discord" }, suppress_event = "maximize fullscreen activate", fullscreen_state = "0 0", tile = true })

-- Spotify: tiled on the active workspace (Spotify wayland has no class for some reason -> initial_title too)
rule({ name = "spotify-class", match = { class = "Spotify" }, suppress_event = "maximize fullscreen", fullscreen_state = "0 0", tile = true })
rule({ name = "spotify-title", match = { initial_title = "Spotify( Free)?" }, suppress_event = "maximize fullscreen", fullscreen_state = "0 0", tile = true })

-- Chat apps: an incoming message fires an activate request which (focus_on_activate=1, no_warps=0) steals
-- focus and warps the cursor; suppress_event activate drops it.
rule({ name = "telegram-no-activate", match = { class = "org.telegram.desktop" }, suppress_event = "activate" })
rule({ name = "whatsapp-no-activate", match = { class = "WhatsApp Desktop" }, suppress_event = "activate" })

-- Telegram: keep the media viewer out of chat groups so its fullscreen does not stick on the chat window
rule({ name = "telegram-media-viewer", match = { class = "org.telegram.desktop", initial_title = "Media viewer" }, group = "barred" })
rule({ name = "telegram-chat", match = { class = "org.telegram.desktop", initial_title = "negative:Media viewer" }, suppress_event = "maximize fullscreen", fullscreen_state = "0 0" })

-- ######## Layer rules ########
for _, ns in ipairs({ "hyprpicker", "logout_dialog", "selection", "wayfreeze" }) do
  layer({ name = "fade-" .. ns, match = { namespace = ns }, animation = "fade" })
end

-- Launcher / Fuzzel (transition; dropped once the solanum launcher exists)
layer({ name = "launcher", match = { namespace = "launcher" }, animation = "popin 80%", blur = true })
layer({ name = "fuzzel", match = { namespace = "fuzzel" }, animation = "popin 80%", blur = true })

-- Wallpaper video
layer({ name = "mpvpaper", match = { namespace = "mpvpaper" }, no_anim = true })

-- Shell layers: caelestia (Phase 1) and solanum (Phase 2+) namespaces
layer({ name = "caelestia-noanim", match = { namespace = "caelestia-(border-exclusion|area-picker)" }, no_anim = true })
layer({ name = "caelestia-fade", match = { namespace = "caelestia-(drawers|background)" }, animation = "fade" })
layer({ name = "qm-noanim", match = { namespace = "solanum-(border-exclusion|area-picker|fade)" }, no_anim = true })
layer({ name = "qm-fade", match = { namespace = "solanum-(drawers|background)" }, animation = "fade" })
