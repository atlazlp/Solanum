-- decoration.lua: caelestia decoration.conf + variables.conf blur/shadow + QM shadow tint (scheme/shadow.conf).
local S = QM.scheme

hl.config({
  decoration = {
    rounding = 15,

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
      range = 28,
      render_power = 2,
      offset = { 0, 8 },
      color = "rgba(" .. S.shadow_tint .. "1a)",
    },
  },
})
