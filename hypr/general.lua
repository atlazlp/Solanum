-- general.lua: general/dwindle/misc/debug/binds/cursor (caelestia general.conf, misc.conf, input.conf tail).
-- Machine-local bits (cursor.no_hardware_cursors, group.drag_into_group, kb_layout) live in local.lua.
local S = QM.scheme

hl.config({
  general = {
    layout = "dwindle",
    allow_tearing = false, -- lets the `immediate` window rule work for games
    gaps_workspaces = 20,
    gaps_in = 5,
    gaps_out = 10,
    -- Nomai-style: crisp 2 px edge; active = primary→tertiary (line + spark), inactive = outline.
    border_size = 2,
    col = {
      active_border = { colors = { S.rgba("primary", "ff"), S.rgba("tertiary", "cc") }, angle = 135 },
      inactive_border = S.rgba("outlineVariant", "88"),
    },
  },

  dwindle = {
    preserve_split = true,
    smart_split = false,
    smart_resizing = true,
  },

  misc = {
    vrr = 1,
    animate_manual_resizes = false,
    animate_mouse_windowdragging = false,
    disable_hyprland_logo = true,
    force_default_wallpaper = 0,
    on_focus_under_fullscreen = 2,
    allow_session_lock_restore = true,
    middle_click_paste = false,
    focus_on_activate = true,
    session_lock_xray = true,
    mouse_move_enables_dpms = true,
    key_press_enables_dpms = true,
    background_color = S.rgb("surfaceContainer"),
  },

  debug = {
    error_position = 1,
  },

  binds = {
    scroll_event_delay = 0,
  },

  cursor = {
    hotspot_padding = 1,
  },
})
