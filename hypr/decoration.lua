-- decoration.lua: caelestia decoration.conf + variables.conf blur/shadow + QM shadow tint (scheme/shadow.conf).
local S = QM.scheme

hl.config({
  decoration = {
    -- Angular Nomai chrome (matches shell chamfer language; Hyprland cannot draw true chamfers).
    rounding = 2,

    blur = {
      enabled = true,
      xray = false,
      special = false,
      ignore_opacity = true, -- allows opacity blurring
      new_optimizations = true,
      popups = true,
      input_methods = true,
      size = 8,
      passes = 2,
    },

    shadow = {
      enabled = true,
      range = 20,
      render_power = 3,
      offset = { 0, 4 },
      -- Soft glow like NomaiFrame's outer line bloom.
      color = "rgba(" .. S.shadow_tint .. "33)",
    },
  },
})
