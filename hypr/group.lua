-- group.lua: caelestia group.conf with the QM-computed groupbar contrast pairs (scheme/groupbar.conf).
-- Upstream group.conf used to override the computed colours; the Lua port applies the computed ones (intended).
local S = QM.scheme

hl.config({
  group = {
    col = {
      border_active = S.rgba("primary", "e6"),
      border_inactive = S.rgba("onSurfaceVariant", "11"),
      border_locked_active = S.rgba("primary", "e6"),
      border_locked_inactive = S.rgba("onSurfaceVariant", "11"),
    },

    groupbar = {
      font_family = "JetBrains Mono NF",
      font_size = 15,
      gradients = true,
      gradient_round_only_edges = false,
      gradient_rounding = 5,
      height = 25,
      indicator_height = 0,
      gaps_in = 3,
      gaps_out = 3,

      text_color = S.rgb(S.gb("active_fg", "onPrimary")),
      text_color_inactive = S.rgb(S.gb("inactive_fg", "onSurface")),
      text_color_locked_active = S.rgb(S.gb("locked_active_fg", "onTertiary")),
      text_color_locked_inactive = S.rgb(S.gb("locked_inactive_fg", "onSecondary")),

      col = {
        active = S.rgba(S.gb("active_bg", "primary"), "f5"),
        inactive = S.rgba(S.gb("inactive_bg", "outlineVariant"), "f5"),
        locked_active = S.rgba(S.gb("locked_active_bg", "tertiary"), "f5"),
        locked_inactive = S.rgba(S.gb("locked_inactive_bg", "secondary"), "f5"),
      },
    },
  },
})
