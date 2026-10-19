-- group.lua: Nomai group borders + groupbar chips with readable contrast on every planet.
-- plugins/groupbar-current keeps the currently shown tab painted with col.active after the
-- group loses focus (Hyprland only does that for the focused window by default).
local S, U = QM.scheme, QM.util

hl.config({
  group = {
    col = {
      border_active = { colors = { S.rgba("primary", "ff"), S.rgba("tertiary", "cc") }, angle = 135 },
      border_inactive = S.rgba("outlineVariant", "88"),
      border_locked_active = S.rgba("tertiary", "ff"),
      border_locked_inactive = S.rgba("secondary", "88"),
    },

    groupbar = {
      font_family = "Space Mono",
      font_size = 13,
      -- gradients must be on so col.active / col.inactive paint the chip fill (not only the indicator).
      gradients = true,
      gradient_round_only_edges = false,
      gradient_rounding = 2,
      height = 22,
      gaps_in = 2,
      gaps_out = 2,
      indicator_height = 0,

      -- Prefer onPrimary (dark warm) over onPrimaryFixed (often pure black) so focused titles stay visible.
      text_color = S.rgb(S.gb("active_fg", "onPrimary")),
      text_color_inactive = S.rgb(S.gb("inactive_fg", "onSurface")),
      text_color_locked_active = S.rgb(S.gb("locked_active_fg", "onTertiary")),
      text_color_locked_inactive = S.rgb(S.gb("locked_inactive_fg", "onSecondaryContainer")),

      col = {
        active = S.rgba(S.gb("active_bg", "primary"), "ff"),
        -- outline / secondaryContainer — never near-black surfaceBright chips.
        inactive = S.rgba(S.gb("inactive_bg", "outline"), "f0"),
        locked_active = S.rgba(S.gb("locked_active_bg", "tertiaryContainer"), "ff"),
        locked_inactive = S.rgba(S.gb("locked_inactive_bg", "secondaryContainer"), "f0"),
      },
    },
  },
})

local function load_groupbar_current()
  local so = U.CFG_DIR .. "/plugins/groupbar-current/groupbar-current.so"
  if not U.exists(so) then
    U.log("groupbar-current.so missing — run: make -C " .. U.CFG_DIR .. "/plugins/groupbar-current")
    return
  end
  local ok_list, plugins = pcall(function()
    return hl.get_loaded_plugins()
  end)
  if ok_list and type(plugins) == "table" then
    for _, p in ipairs(plugins) do
      local name = U.field(p, "name") or ""
      if name == "groupbar-current" or tostring(U.field(p, "path") or ""):find("groupbar-current", 1, true) then
        return
      end
    end
  end
  local ok, err = pcall(function()
    hl.plugin.load(so)
  end)
  if not ok then
    U.log("groupbar-current load failed: " .. tostring(err))
  end
end

U.on_live(load_groupbar_current)
