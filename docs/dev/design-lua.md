# Design: Hyprland Lua config (`hypr/`)

Reference for the Lua port. Verified against Hyprland 0.56.2 sources, `/usr/share/hypr/stubs/hl.meta.lua`
and `/usr/share/hypr/hyprland.lua`.

## Runtime facts
- Precedence: `hyprland.lua` wins over `hyprland.conf` in `~/.config/hypr`; `-c`/`$HYPRLAND_CONFIG` override.
- No sandbox: `luaL_openlibs` (io, os, string, table, math, package, utf8, coroutine, debug minus sethook). Lua 5.5.
- `require(path)` is relative to the config dir, supports `./dir/*` globs, runs each file in a protected scope
  (an error in one file does not abort others; a *missing* module throws in the caller -> use `pcall(require, ...)`).
  Every required file joins the inotify watch set -> autoreload on save. `dofile`/`io.open` do not add watches.
  Original require is `__require`. `package.path` has `<cfgdir>/?.lua;<cfgdir>/?/init.lua`.
- Reload = full re-evaluation: timers, event subscriptions, binds, rules, monitor rules are cleared and a new state
  is created. Top-level `hl.exec_cmd` re-runs on every reload (it is `exec`, not `exec-once`). One-shots go in
  `hl.on("hyprland.start", fn)`.
- Callback budgets: config reload 1500 ms, event cb 50 ms, keybind cb 100 ms, timer cb 50 ms. Never block
  (no io.popen, no sleeps); spawn with `hl.exec_cmd` (async).
- `Hyprland --verify-config -c file.lua` validates load-time code (prints `config ok`). `hyprctl repl`/`eval` only
  work once the Lua manager is active. `hyprctl reload [config-only]`.
- Emergency binds (SUPER+Q terminal, SUPER+R run, SUPER+M exit) appear if the config fails to load.

## API cheatsheet
- `hl.config({ general = {...}, decoration = {...}, misc = {...}, input = {...}, ... })` (nested tables, keys with
  underscores). Colours: `"rgba(RRGGBBAA)"`, `"rgb(RRGGBB)"`, or `0xAARRGGBB`. Gradient: `{ colors = {...}, angle = 45 }`.
- `hl.bind(keys, dispatcher_or_fn, opts)`. keys split on `+`, modifiers UPPERCASE (`SUPER CTRL SHIFT ALT`), key via
  xkb keysym name case-insensitive (`Super_L`, `Tab`, `Page_Up`, `mouse:275`, `mouse_up`, `code:N`, `XF86AudioPlay`).
  opts: `repeating locked release non_consuming transparent ignore_mods dont_inhibit long_press submap_universal
  click drag description device allow_input_capture mouse`. `release+repeating` is an error. Returns a handle
  with `:set_enabled(bool)`, `:remove()`. `hl.unbind(keys)`.
  Flag map from hyprlang: bind->{} binde->{repeating} bindl->{locked} bindle->{locked,repeating} bindr->{release}
  bindm->drag/resize dispatcher + {mouse=true} bindc->{click} bindi->{ignore_mods} bindin->{ignore_mods,non_consuming}
  bindnitn->{non_consuming,ignore_mods,transparent}.
- Release binds are matched against the submap active at press unless `submap_universal = true`.
- Multiple binds on the same key all fire; a `non_consuming` one does not suppress the key.
- `catchall` only inside `hl.define_submap(name, fn)` (or `(name, "reset_key", fn)`). Default submap is `""`:
  `hl.dsp.submap("reset")`. Never name a submap `global`.
- Mouse drag: `hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })`, resize via `hl.dsp.window.resize()`.
- Dispatchers (`hl.dispatch(d)` or as bind target): `hl.dsp.focus{direction|monitor|workspace|window|last|urgent_or_last}`,
  `hl.dsp.window.move{direction[,group_aware]}|{x,y,relative}|{workspace,follow}|{monitor,follow}|{out_of_group=true}`,
  `hl.dsp.window.resize{x,y,relative}` (numbers only, no %), `.fullscreen{mode="fullscreen"|"maximized",action}`,
  `.fullscreen_state{internal,client,action,window}`, `.center()`, `.pin()`, `.float()`, `.close([win])`,
  `.cycle_next{...}`, `.swap{...}`, `.pseudo()`, `.set_prop`, `.tag`, `hl.dsp.workspace.toggle_special(name)`
  ("special:" auto-prefixed), `hl.dsp.group.toggle()/next()/prev()/lock_active{action}/active{index,window}`,
  `hl.dsp.dpms{action,monitor}`, `hl.dsp.submap(name)`, `hl.dsp.exec_cmd(cmd[,rules])`, `hl.dsp.global("ns:name")`,
  `hl.dsp.send_shortcut{mods,key,window}`, `hl.dsp.pass{window}`, `hl.dsp.layout(msg)`, `hl.dsp.no_op()`, `hl.dsp.exit()`.
- Events `hl.on(name, cb)`: hyprland.start, hyprland.shutdown, config.reloaded, config.props_refreshed,
  window.open/open_early/close/destroy/active(w, reason)/title/class/fullscreen/urgent/pin/kill/move_to_workspace/update_rules,
  workspace.active/created/removed/move_to_monitor(ws,m)/special_active(ws,m), monitor.added/removed/focused(m)/layout_changed(),
  layer.opened/closed, keybinds.submap(name), input.keyboard.key(keycode+8, time_ms, state 1=press 0=release) (ints only,
  no keysym/mods, cannot consume), screenshare.state(bool,int,name). Returns subscription with `:remove()`.
- Timers: `hl.timer(fn, { timeout = ms, type = "repeat"|"oneshot" })` -> `:set_enabled(bool)`, `:is_enabled()`, `:set_timeout()`.
- Queries: `hl.get_windows{class=,title=,floating=,mapped=,monitor=,workspace=,tag=}` (class/title EXACT match;
  mapped=true default), `hl.get_active_window()`, `hl.get_last_window()`, `hl.get_window(sel)`, `hl.get_monitors()`,
  `hl.get_monitor(sel)`, `hl.get_active_monitor()`, `hl.get_monitor_at_cursor()`, `hl.get_workspaces()`,
  `hl.get_workspace(sel)`, `hl.get_active_workspace([mon])`, `hl.get_active_special_workspace([mon])`,
  `hl.get_workspace_windows(ws)`, `hl.get_current_submap()`, `hl.is_key_down(key)`, `hl.get_config(key)`,
  `hl.get_cursor_pos()`, `hl.get_layers{namespace=,monitor=}`, `hl.version()`.
- Window fields: address ("0x..."), class, initial_class, title, initial_title, pid, mapped, hidden, visible, floating,
  fullscreen (int), fullscreen_client (int), pinned, size{x,y}, at{x,y}, workspace (ws|nil), monitor (mon|nil),
  group (HL.Group{members,current,current_index,size,locked,add,remove}|nil), focus_history_id, content_type, xwayland,
  tags, inhibiting_idle, active.
- Monitor fields: name, id, x, y, width, height (untransformed mode size), refresh_rate, scale, transform, position{x,y},
  size, reserved{top,right,bottom,left}, active_workspace, active_special_workspace, focused, dpms_status, description,
  serial, vrr_active; methods set_workspace{workspace=}, set_special_workspace{workspace=}|nil.
- Workspace fields: id, name, special, windows (count), is_empty, monitor, active, visible, has_fullscreen, last_window,
  config_name; methods get_windows(), get_groups().
- Rules: `hl.window_rule({ name=, enabled=, match = { class, title, initial_class, initial_title, tag, xwayland, float,
  fullscreen, pin, focus, group, modal, workspace, content, xdg_tag, fullscreen_state_client/internal }, <effects> })`.
  Effects (see `/usr/include/hyprland/src/config/lua/bindings/LuaBindingsInternal.hpp:49-107`): float, tile, center,
  pin, no_initial_focus, no_focus, fullscreen_state ("0 0"), move, size (2-table or string of muParser expressions with
  monitor_w monitor_h window_w window_h cursor_x cursor_y), workspace ("special:x" / "unset"), group ("barred"|"set"...),
  suppress_event ("maximize fullscreen activate"), idle_inhibit ("always"), opacity ("0.95 override"), rounding, no_blur,
  no_dim, no_shadow, keep_aspect_ratio, immediate, opaque, xray, border_size, no_anim, dim_around... Negation:
  `"negative:regex"`. Regex backslashes doubled in Lua strings. Handle has `:set_enabled()`.
- `hl.layer_rule({ name=, match = { namespace = "regex" }, animation = "fade"|"popin 80%", blur=, no_anim=, xray=,
  ignore_alpha=, order=, above_lock= })`.
- `hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out=, gaps_in=, monitor=, default=, persistent=, layout=, ... })`.
- `hl.monitor({ output=, mode=, position=, scale=, transform=, disabled=, mirror=, vrr=, bitdepth=, cm=, reserved_area= })`.
  Calling again for the same output merges fields and schedules a monitor refresh (usable at runtime). `output = ""` = fallback.
- `hl.env(name, value[, dbus])`. `hl.curve(name, { type = "bezier", points = {{x,y},{x,y}} })` or
  `{ type = "spring", mass, stiffness, dampening }`. `hl.animation({ leaf=, enabled=, speed=, bezier=|spring=, style= })`
  (curve must exist before use). `hl.gesture({ fingers, direction, action = "workspace"|"special"|"resize"|"move"|"close"|
  "float"|"fullscreen"|"cursor_zoom"|"scroll_move"|"unset"|function, mods, scale, workspace_name, mode })`.
  `hl.device({ name=, ... })`. `hl.permission({ binary, type, mode })`. `hl.exec_cmd(cmd, rules)`.
  `hl.notification.create({ text, timeout, color, icon, font_size })`. `hl.clear_crashed_lockscreen()`.
  `hl.exec_scheduled_prop_refresh_immediately()` (after hl.config at runtime, sparingly).

## Translation targets (values from caelestia variables.conf + user files)
- general: layout dwindle, allow_tearing false, gaps_workspaces 20, gaps_in 5, gaps_out 10, border_size 1,
  col.active_border rgba(primary e6), col.inactive_border rgba(onSurfaceVariant 11). dwindle: preserve_split,
  smart_split false, smart_resizing. misc: vrr 1, animate_manual_resizes false, animate_mouse_windowdragging false,
  disable_hyprland_logo, force_default_wallpaper 0, on_focus_under_fullscreen 2, allow_session_lock_restore,
  middle_click_paste false, focus_on_activate true, session_lock_xray, mouse_move_enables_dpms, key_press_enables_dpms,
  background_color rgb(surfaceContainer). debug.error_position 1. binds.scroll_event_delay 0. cursor.hotspot_padding 1,
  no_hardware_cursors true (local). input: kb_layout br (local), numlock_by_default false, repeat_delay 250,
  repeat_rate 35, focus_on_close 1, follow_mouse 1, touchpad natural_scroll/disable_while_typing/scroll_factor 0.3.
  gestures: workspace_swipe_distance 700, cancel_ratio 0.15, min_speed_to_force 5, direction_lock true, threshold 10,
  create_new true. scrolling: fullscreen_on_one_column, focus_fit_method 1, column_width 0.5, follow_focus,
  follow_min_visible 0.0, explicit_column_widths "0.35, 0.5, 0.65, 1.0". decoration: rounding 15, blur enabled
  size 8 passes 2 xray false special false ignore_opacity new_optimizations popups input_methods; shadow enabled
  range 28 render_power 2 offset {0,8} color rgba(shadow_tint 1a). group: drag_into_group 1 (local), border colours as
  general, groupbar font "JetBrains Mono NF" 15, gradients true, gradient_round_only_edges false, gradient_rounding 5,
  height 25, indicator_height 0, gaps_in 3, gaps_out 3, text/col from scheme.groupbar contrast pairs.
- Animations: curves specialWorkSwitch {0.05,0.7},{0.1,1}; emphasizedAccel {0.3,0},{0.8,0.15}; emphasizedDecel
  {0.05,0.7},{0.1,1}; standard {0.2,0},{0,1}. Leaves: layersIn 5 emphasizedDecel slide; layersOut 4 emphasizedAccel slide;
  fadeLayers 5 standard; windowsIn 5 emphasizedDecel; windowsOut 3 emphasizedAccel; windowsMove 6 standard;
  workspaces 5 standard; specialWorkspace 4 specialWorkSwitch "slidefadevert 15%"; fade 6 standard; fadeDim 6 standard;
  border 6 standard.
- Monitors: HDMI-A-1 1366x768@59.79 0x0 scale 1 transform 1; DP-2 1920x1080@143.99 768x0; DP-3 1366x768@59.79 2688x312;
  fallback `output=""` preferred auto 1.
- Workspace rules: w[tv1]s[false] gaps_out 10; f[1]s[false] gaps_out 10.
- Layer rules: fade on hyprpicker|logout_dialog|selection|wayfreeze; no_anim mpvpaper; quantum-moon-(drawers|background)
  fade; quantum-moon-(area-picker|fade|border-exclusion) no_anim; (transition) caelestia-* equivalents + launcher/fuzzel popin blur.
- Window rules: see caelestia rules.conf:1-90 + hypr-user.conf:49-101 (final intent: Discord/Spotify tiled + suppress
  maximize fullscreen + fullscreen_state 0 0; Telegram/Discord/WhatsApp suppress_event activate; Telegram media viewer
  group barred + non-viewer suppress fullscreen; Proton ghosts no_focus/no_initial_focus; games opaque immediate
  idle_inhibit always; Waydroid float 1920x1080 center opaque idle_inhibit; PiP float pin keep_aspect move bottom-right).
- Workspace group math (wsaction.fish): in_group(n) = floor((a-1)/10)*10 + n; group(n) = (n-1)*10 + a%10.
- exec-once -> hyprland.start: uwsm finalize (only if UWSM), wl-paste --type text/--type image --watch cliphist store,
  trash-empty 30, hyprctl setcursor capitaine-cursors 24, gsettings cursor-theme/cursor-size, hyprresume -c, autolock on login.
  Non-UWSM fallback branch also starts: shell, hyprpaper, hyprsunset, qm-apply --persisted && qm-video-watch,
  lan-mouse/llm-tray sessions, audio inhibit, suspend-resume watch.

## Feature pseudocode
See the plan file sections (alttab, special, launcher_super, hotplug, gamemode, proton_ghosts, telegram, mouse, night, pip).
Key points:
- launcher_super: evdev KEY_LEFTMETA=125, KEY_RIGHTMETA=126 -> keycodes 133/134 in the event (keycode+8). Super press
  starts; any other key press while down = interrupted; release within 400 ms and not interrupted -> launcher toggle.
  8 mouse interrupt binds `SUPER + mouse:272..277/mouse_up/mouse_down` with {non_consuming, ignore_mods}.
- hotplug: sort monitors by (x,y); logical width accounts for transform 1/3 and scale; if preferred main absent -> pack
  left-to-right with hl.monitor re-specs, host = rightmost, marker file STATE/main-monitor-fallback; on return re-apply
  defaults; debounce 800 ms; notify shell `monitors hotplug <host>`; run qm-apply --persisted.
- gamemode: is_game = class starts with steam_app_ or == gamescope or content_type == "game"; active when such a window is
  visible or fullscreen; marker $XDG_RUNTIME_DIR/quantum-moon-game-mode.active; pause/resume mpvpaper via
  hypr/scripts/qm-mpv-ipc; tell shell `gameMode set true|false`.
- mouse submaps: press mouse:275 -> submap mousedragthumb unless active window is steam_app_*; release -> reset with
  {release=true, submap_universal=true}; mouse:276 -> mouse5group with mouse:272 {click=true} toggling group / out of group.

## Scheme
`qm-apply` writes `~/.local/state/quantum-moon/scheme.lua` (atomic) =
`return { slug=, night_temperature=, colours={...}, shadow_tint="rrggbb", groupbar={active_bg=key,...} }` and runs
`hyprctl reload`. `lib/scheme.lua` loads it with `pcall(dofile)` (NOT require) and falls back to `lib/scheme-default.lua`.
