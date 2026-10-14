-- input.lua: caelestia input.conf, gestures.conf, scrolling.conf. kb_layout br / follow_mouse come from local.lua.
hl.config({
  input = {
    kb_layout = "us",
    numlock_by_default = false,
    repeat_delay = 250,
    repeat_rate = 35,
    focus_on_close = 1,
    touchpad = {
      natural_scroll = true,
      disable_while_typing = true,
      scroll_factor = 0.3,
    },
  },

  gestures = {
    workspace_swipe_distance = 700,
    workspace_swipe_cancel_ratio = 0.15,
    workspace_swipe_min_speed_to_force = 5,
    workspace_swipe_direction_lock = true,
    workspace_swipe_direction_lock_threshold = 10,
    workspace_swipe_create_new = true,
  },

  scrolling = {
    fullscreen_on_one_column = true,
    focus_fit_method = 1,
    column_width = 0.5,
    follow_focus = true,
    follow_min_visible = 0.0,
    explicit_column_widths = "0.35, 0.5, 0.65, 1.0",
  },
})

-- gesture = 4, horizontal, workspace
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
-- gesture = 3, up, special, special
hl.gesture({ fingers = 3, direction = "up", action = "special", workspace_name = "special" })
-- gesture = 3, down, dispatcher, exec, caelestia toggle specialws  (ported natively in features/special.lua)
hl.gesture({
  fingers = 3,
  direction = "down",
  action = function()
    if QM.special then QM.special.toggle_specialws() end
  end,
})
-- gesture = 4, down, dispatcher, exec, systemctl suspend-then-hibernate
hl.gesture({
  fingers = 4,
  direction = "down",
  action = function() hl.exec_cmd("systemctl suspend-then-hibernate") end,
})
