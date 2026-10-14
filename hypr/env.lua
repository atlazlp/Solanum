-- env.lua: caelestia hyprland/env.conf + ~/.config/caelestia/hypr-env-qt.conf.
-- Never set PATH here (hypr-user.conf:3). Under UWSM (Phase 4) the toolkit vars move to ~/.config/uwsm/env-hyprland.

-- Themes
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct") -- hypr-env-qt.conf overrides caelestia's qtengine
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("XCURSOR_THEME", "capitaine-cursors")
hl.env("XCURSOR_SIZE", "24")

-- Toolkit backends
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland,x11,windows")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- XDG
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Others
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

QM.cursor = { theme = "capitaine-cursors", size = 24 }
