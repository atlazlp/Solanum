extends Node

## Solanum wallpaper glue: control-file IPC, solar.json export, planet/sun hover pause.
## Enabled when QM_WALLPAPER=1 (set by qm-video-restart / qm-godot helpers).

const CONTROL_REL := "solanum/godot-control.json"
const SOLAR_REL := "solanum/solar.json"
const WINDOW_CLASS := "qm-solar-wallpaper"
const HOVER_POLL_SEC := 0.05
const OVERLAY_POLL_SEC := 0.25
const EXPORT_SEC := 0.08
const CONTROL_POLL_SEC := 0.1
## Client classes that sit on the wallpaper monitor but should not force a pause.
const OVERLAY_IGNORE_CLASSES: PackedStringArray = [
	"qm-solar-wallpaper",
	"org.quickshell",
	"quickshell",
	"qm",
]
## Small pad beyond projected mesh radius (was 18 — too forgiving).
const HIT_PAD_PX := 3.0
## Ring sits outside the OPC orbit around Giant's Deep (visualiser bars).
const GD_RING_OPC_SCALE := 1.2
## Ring radius as a multiple of the planet mesh radius (moons excluded).
const BODY_RING_RADIUS_SCALE := 1.85
## Twins barycenter ring is a bit generous — pull it in.
const TWINS_RING_SCALE := 0.78
const RING_BODY_IDS := ["hourglass_twins", "timber_hearth", "brittle_hollow", "giants_deep", "dark_bramble"]
## Subtrees under Body that are not the planet disc (moons / OPC).
const RING_SKIP_SUBTREES: PackedStringArray = [
	"Moon_Pivot",
	"VolcanicMoon_Pivot",
	"OrbitalProbeCannon_Pivot",
	"OPC_OrbitGapAnchor",
]

var _wallpaper: bool = false
var _hover_pause: bool = false
var _hover_body: String = ""
var _menu_hold: bool = false
var _menu_hold_body: String = ""
var _overlay_pause: bool = false
var _overlay_enabled: bool = true
var _control_pause: bool = false
var _game_pause: bool = false
var _hover_accum: float = 0.0
var _overlay_accum: float = 0.0
var _export_accum: float = 0.0
var _control_accum: float = 0.0
var _control_path: String = ""
var _solar_path: String = ""
var _last_control_mtime: int = -1
var _last_supernova_token: String = ""
var _last_orbit_token: String = ""
var _last_overview_token: String = ""
var _orbit_body_id: String = ""
var _overview_scale: float = 4.0
var _video_body: String = ""
var _video_hold: float = 0.0
var _video_ready: bool = false
var _orbit_settled: bool = false
var _lines_fade: float = -1.0
var _interloper_shown: bool = true
var _sun_body: Node3D
var _sun_base_scale: Vector3 = Vector3.ONE
var _sun_light: Light3D
var _sun_light_energy: float = 13.0
var _sun_fill: Light3D
var _sun_fill_energy: float = 0.2
var _sun_pulse_token: String = ""
var _sun_pulse_dir: String = ""
var _sun_pulse_start_ms: int = 0
var _sun_pulse_ms: int = 1000
const ORBIT_TIME_SCALE := 2.0
const ORBIT_FRAME_SCALE := 2.75
var _solar: Node
var _body_roots: Dictionary = {}
var _cam: Camera3D
var _last_cursor_local: Vector2 = Vector2(-1, -1)
var _last_win_at: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Freeze the sim before bodies move, so the camera ease isn't chasing a stale position.
	process_priority = -40
	_wallpaper = OS.get_environment("QM_WALLPAPER") == "1"
	if not _wallpaper:
		set_process(false)
		return
	var runtime := OS.get_environment("XDG_RUNTIME_DIR")
	if runtime.is_empty():
		runtime = "/tmp"
	_control_path = runtime.path_join(CONTROL_REL)
	_solar_path = runtime.path_join(SOLAR_REL)
	DirAccess.make_dir_recursive_absolute(_control_path.get_base_dir())
	_apply_wallpaper_window()
	_hide_debug_hud()
	call_deferred("_bind_scene")
	var scale_env := OS.get_environment("QM_TIME_SCALE")
	if not scale_env.is_empty():
		_overview_scale = float(scale_env)
	WallpaperBus.set_time_scale(_overview_scale)
	_read_control(true)
	set_process(true)


func _process(delta: float) -> void:
	_control_accum += delta
	if _control_accum >= CONTROL_POLL_SEC:
		_control_accum = 0.0
		_read_control(false)
	_hover_accum += delta
	if _hover_accum >= HOVER_POLL_SEC:
		_hover_accum = 0.0
		_update_hover()
	_overlay_accum += delta
	if _overlay_accum >= OVERLAY_POLL_SEC:
		_overlay_accum = 0.0
		_update_overlay_pause()
	_export_accum += delta
	if _export_accum >= EXPORT_SEC:
		_export_accum = 0.0
		_export_solar()
	_sync_camera_phase(delta)
	_apply_sun_pulse()
	_apply_pause_state()
	WallpaperBus.tick_speed(delta)


func _apply_wallpaper_window() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_title(WINDOW_CLASS)
	ProjectSettings.set_setting("application/config/name", WINDOW_CLASS)


func _hide_debug_hud() -> void:
	var hud := get_tree().root.find_child("DebugHud", true, false)
	if hud:
		hud.visible = false
		hud.process_mode = Node.PROCESS_MODE_DISABLED


func _bind_scene() -> void:
	_cam = get_viewport().get_camera_3d()
	var solar := get_tree().root.find_child("SolarSystemMode", true, false)
	_solar = solar
	if solar == null:
		return
	_body_roots.clear()
	_register_body("sun", solar.find_child("Sun", true, false) as Node3D)
	_register_body("hourglass_twins", solar.find_child("OrbitRoot_HGT", true, false) as Node3D)
	_register_body("timber_hearth", solar.find_child("OrbitRoot_TH", true, false) as Node3D)
	_register_body("brittle_hollow", solar.find_child("OrbitRoot_BH", true, false) as Node3D)
	_register_body("giants_deep", solar.find_child("OrbitRoot_GD", true, false) as Node3D)
	_register_body("dark_bramble", solar.find_child("OrbitRoot_DB", true, false) as Node3D)
	_register_body("quantum_moon", solar.find_child("QuantumMoon", true, false) as Node3D)
	# OPC orbit gap anchor (preferred) or cannon pivot — used for visualiser ring radius.
	var opc := solar.find_child("OPC_OrbitGapAnchor", true, false) as Node3D
	if opc == null:
		opc = solar.find_child("OrbitalProbeCannon_Pivot", true, false) as Node3D
	_register_body("opc", opc)
	_bind_sun()
	_read_control(true)
	_sync_camera_phase(0.0)


func _show_orbit_line(body_id: String, shown: bool) -> void:
	if body_id.is_empty() or _solar == null or not _solar.has_method("set_orbit_line_visible"):
		return
	var node: Node = _body_roots.get(body_id)
	if node:
		_solar.set_orbit_line_visible(node, shown)


func _snap_camera_overview() -> void:
	_video_body = ""
	_video_ready = false
	_video_hold = 0.0
	_orbit_body_id = ""
	_set_lines_fade(1.0)
	_set_interloper_visible(true)
	WallpaperBus.set_time_scale(_overview_scale)
	if _cam and _cam.has_method("snap_overview"):
		_cam.snap_overview()


func _return_overview() -> void:
	_video_body = ""
	_video_ready = false
	_video_hold = 0.0
	if _cam and _cam.has_method("return_overview"):
		_cam.return_overview()
	else:
		_snap_camera_overview()


func _sync_camera_phase(delta: float) -> void:
	var transitioning := false
	var arrived := false
	var amount := 0.0
	if _cam != null and _cam.has_method("is_transitioning"):
		transitioning = bool(_cam.call("is_transitioning"))
		arrived = bool(_cam.call("orbit_arrived"))
		amount = float(_cam.call("transition_orbit_amount"))
	_orbit_settled = arrived
	WallpaperBus.set_sim_frozen(transitioning)
	var fade := 1.0
	var show_interloper := true
	if transitioning:
		fade = 1.0 - amount
		show_interloper = amount < 0.08
	elif arrived:
		fade = 0.0
		show_interloper = false
		if not is_equal_approx(WallpaperBus.time_scale, ORBIT_TIME_SCALE):
			WallpaperBus.set_time_scale(ORBIT_TIME_SCALE)
		if not _video_body.is_empty() and not _video_ready:
			_video_hold += delta
			if _video_hold >= 0.55:
				_video_ready = true
	else:
		if not _orbit_body_id.is_empty():
			_orbit_body_id = ""
		if not is_equal_approx(WallpaperBus.time_scale, _overview_scale):
			WallpaperBus.set_time_scale(_overview_scale)
		_video_ready = false
		_video_hold = 0.0
	_apply_line_fade(fade)
	if show_interloper != _interloper_shown:
		_interloper_shown = show_interloper
		_set_interloper_visible(show_interloper)
	var focus := ""
	if _cam != null and _cam.has_method("orbit_target") and _cam.orbit_target() != null:
		focus = _orbit_body_id
	if _solar != null and _solar.has_method("set_orbit_cull"):
		_solar.set_orbit_cull(focus)
	var close_blend := 0.0
	if not _orbit_body_id.is_empty():
		if arrived:
			close_blend = 1.0
		elif transitioning:
			close_blend = amount
	if _solar != null and _solar.has_method("set_brittle_hollow_blend"):
		_solar.set_brittle_hollow_blend(close_blend if _orbit_body_id == "brittle_hollow" else 0.0)
	if _solar != null and _solar.has_method("set_giants_deep_blend"):
		_solar.set_giants_deep_blend(close_blend if _orbit_body_id == "giants_deep" else 0.0)


func _apply_line_fade(amount: float) -> void:
	if is_equal_approx(amount, _lines_fade):
		return
	_lines_fade = amount
	_set_lines_fade(amount)


func _begin_planet_orbit(body_id: String, snap: bool = false) -> void:
	var node: Node3D = _body_roots.get(body_id) as Node3D
	if node == null or _cam == null or not _cam.has_method("begin_orbit"):
		return
	_orbit_body_id = body_id
	_video_ready = false
	_video_hold = 0.0
	if _cam.has_method("orbit_target") and _cam.orbit_target() == node and _cam.is_orbiting():
		return
	var reach := _estimate_radius_m(node)
	var frame := clampf(reach * ORBIT_FRAME_SCALE, 2000.0, 18000.0)
	if snap and _cam.has_method("snap_orbit"):
		_cam.snap_orbit(node, frame)
	else:
		_cam.begin_orbit(node, frame)


func _set_lines_fade(amount: float) -> void:
	if _solar != null and _solar.has_method("set_orbit_lines_fade"):
		_solar.set_orbit_lines_fade(amount)


func _set_interloper_visible(shown: bool) -> void:
	if _solar != null and _solar.has_method("set_interloper_visible"):
		_solar.set_interloper_visible(shown)


func _register_body(id: String, node: Node3D) -> void:
	if node:
		_body_roots[id] = node


func _bind_sun() -> void:
	var sun := _body_roots.get("sun") as Node3D
	if sun == null:
		return
	_sun_body = sun.get_node_or_null("Body") as Node3D
	if _sun_body:
		_sun_base_scale = _sun_body.scale
	_sun_light = sun.get_node_or_null("SunLight") as Light3D
	if _sun_light:
		_sun_light_energy = _sun_light.light_energy
	_sun_fill = sun.get_node_or_null("SunFill") as Light3D
	if _sun_fill:
		_sun_fill_energy = _sun_fill.light_energy


func _note_sun_pulse(d: Dictionary) -> void:
	var token := str(d.get("sun_pulse_token", ""))
	if token.is_empty() or token == _sun_pulse_token:
		return
	_sun_pulse_token = token
	var dir := str(d.get("sun_pulse", ""))
	if dir != "out" and dir != "in":
		_sun_pulse_dir = ""
		return
	var start := int(d.get("sun_pulse_start", 0))
	var dur := maxi(int(d.get("sun_pulse_ms", 1000)), 1)
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	if now > start + dur:
		_sun_pulse_dir = ""
		return
	_sun_pulse_dir = dir
	_sun_pulse_start_ms = start
	_sun_pulse_ms = dur


func _inout_quad(t: float) -> float:
	## Qt Easing.InOutQuad, same curve as the travel fade.
	var u := clampf(t, 0.0, 1.0)
	if u < 0.5:
		return 2.0 * u * u
	return 1.0 - pow(-2.0 * u + 2.0, 2.0) / 2.0


func _apply_sun_pulse() -> void:
	if _sun_pulse_dir.is_empty() or _sun_body == null:
		return
	if WallpaperBus.supernova_active:
		_sun_pulse_dir = ""
		return
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	var u := clampf(float(now - _sun_pulse_start_ms) / float(_sun_pulse_ms), 0.0, 1.0)
	var e := _inout_quad(u)
	var s := (1.0 - e) if _sun_pulse_dir == "out" else e
	_sun_body.scale = _sun_base_scale * s
	if _sun_light:
		_sun_light.light_energy = _sun_light_energy * s
	if _sun_fill:
		_sun_fill.light_energy = _sun_fill_energy * s
	if u >= 1.0:
		_sun_pulse_dir = ""


func _read_control(force: bool) -> void:
	if _control_path.is_empty() or not FileAccess.file_exists(_control_path):
		return
	var mtime := FileAccess.get_modified_time(_control_path)
	if not force and mtime == _last_control_mtime:
		return
	_last_control_mtime = mtime
	var f := FileAccess.open(_control_path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	if d.has("pause"):
		_control_pause = bool(d["pause"])
	if d.has("menu_hold"):
		_menu_hold = bool(d["menu_hold"])
	if d.has("game_pause"):
		_game_pause = bool(d["game_pause"])
	if d.has("overlay_pause"):
		_overlay_enabled = bool(d["overlay_pause"])
	if d.has("time_scale"):
		_overview_scale = float(d["time_scale"])
		if _orbit_body_id.is_empty():
			WallpaperBus.set_time_scale(_overview_scale)
	if d.has("qm_host"):
		var host := str(d["qm_host"])
		if not host.is_empty() and host != "eye-of-the-universe":
			WallpaperBus.set_qm_host(host)
	_note_sun_pulse(d)
	var sn_token := str(d.get("supernova_token", ""))
	if not sn_token.is_empty() and sn_token != _last_supernova_token:
		_last_supernova_token = sn_token
		_snap_camera_overview()
		WallpaperBus.trigger_supernova()
	if d.has("video_body"):
		_video_body = str(d["video_body"])
	var orbit_token := str(d.get("orbit_token", ""))
	if not orbit_token.is_empty() and orbit_token != _last_orbit_token:
		var orbit_body := str(d.get("orbit_body", ""))
		var orbit_snap := bool(d.get("orbit_snap", false))
		var cam_ready := _cam != null and _cam.has_method("begin_orbit") and not _body_roots.is_empty()
		if not cam_ready:
			# Fresh boot reads this before the camera exists. A snap request waits
			# for _bind_scene. Anything else is a leftover token from the last session.
			if not orbit_snap:
				_last_orbit_token = orbit_token
		elif not WallpaperBus.supernova_active and not orbit_body.is_empty():
			_last_orbit_token = orbit_token
			_begin_planet_orbit(orbit_body, orbit_snap)
		else:
			_last_orbit_token = orbit_token
	var overview_token := str(d.get("overview_token", ""))
	if not overview_token.is_empty() and overview_token != _last_overview_token:
		_last_overview_token = overview_token
		_return_overview()


func _apply_pause_state() -> void:
	var want := _control_pause or _game_pause or _hover_pause or _overlay_pause
	if want:
		WallpaperBus.pause()
	else:
		WallpaperBus.resume()


func _ignore_overlay_class(cls: String) -> bool:
	var c := cls.to_lower()
	for ign in OVERLAY_IGNORE_CLASSES:
		if c == ign.to_lower() or c.begins_with(ign.to_lower()):
			return true
	return false


## Pause when any normal window shares the wallpaper's monitor (shell / wallpaper ignored).
func _update_overlay_pause() -> void:
	if not _overlay_enabled:
		_overlay_pause = false
		return
	var js := _hyprctl(PackedStringArray(["-j", "clients"]))
	if js.is_empty():
		_overlay_pause = false
		return
	var data: Variant = JSON.parse_string(js)
	if typeof(data) != TYPE_ARRAY:
		_overlay_pause = false
		return
	var wallpaper_mon := -1
	for item in data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		if str(d.get("class", "")) != WINDOW_CLASS:
			continue
		wallpaper_mon = int(d.get("monitor", -1))
		break
	if wallpaper_mon < 0:
		_overlay_pause = false
		return
	for item2 in data:
		if typeof(item2) != TYPE_DICTIONARY:
			continue
		var c: Dictionary = item2
		if int(c.get("monitor", -999)) != wallpaper_mon:
			continue
		if not bool(c.get("mapped", true)):
			continue
		if bool(c.get("hidden", false)):
			continue
		var cls := str(c.get("class", ""))
		if _ignore_overlay_class(cls):
			continue
		var ws: Variant = c.get("workspace", {})
		if typeof(ws) == TYPE_DICTIONARY:
			var wname := str((ws as Dictionary).get("name", ""))
			if wname.begins_with("special"):
				continue
		_overlay_pause = true
		return
	_overlay_pause = false


func _update_hover() -> void:
	if _cam == null or _body_roots.is_empty():
		_hover_pause = false
		_hover_body = ""
		return
	var cursor := _cursor_in_viewport()
	_last_cursor_local = cursor
	if cursor.x < 0.0:
		_hover_pause = false
		_hover_body = ""
		return
	var hit_id := ""
	for id in ["sun", "hourglass_twins", "timber_hearth", "brittle_hollow", "giants_deep", "dark_bramble"]:
		var node: Node3D = _body_roots.get(id) as Node3D
		if node == null:
			continue
		var info := _project_body(node)
		if not info.get("visible", false):
			continue
		var dx: float = cursor.x - float(info["x"])
		var dy: float = cursor.y - float(info["y"])
		var r: float = maxf(float(info["r_px"]) + HIT_PAD_PX, 12.0)
		if dx * dx + dy * dy <= r * r:
			hit_id = id
			break
	if not hit_id.is_empty():
		_menu_hold_body = hit_id
	elif _menu_hold and not _menu_hold_body.is_empty():
		hit_id = _menu_hold_body
	elif not _menu_hold:
		_menu_hold_body = ""
	_hover_body = hit_id
	var orbiting := false
	if _cam != null and _cam.has_method("is_orbiting"):
		orbiting = bool(_cam.call("is_orbiting"))
	_hover_pause = not orbiting and not hit_id.is_empty()


func _hyprctl(args: PackedStringArray) -> String:
	var out: Array = []
	var err := OS.execute("hyprctl", args, out, true)
	if err != 0 or out.is_empty():
		return ""
	return str(out[0]).strip_edges()


## Global cursor → wallpaper window local pixels.
## Prefer Hyprland client geometry: DisplayServer.window_get_position() is wrong for
## hyprwinwrap (hidden) wallpaper windows on Wayland (often reports 0,0).
func _cursor_in_viewport() -> Vector2:
	var raw := _hyprctl(PackedStringArray(["cursorpos"]))
	if raw.is_empty():
		return Vector2(-1, -1)
	var parts := raw.split(",")
	if parts.size() < 2:
		return Vector2(-1, -1)
	var gx := float(parts[0].strip_edges())
	var gy := float(parts[1].strip_edges())

	var win_at := _wallpaper_window_at()
	var win_size := _wallpaper_window_size()
	_last_win_at = win_at
	if win_size.x < 1.0 or win_size.y < 1.0:
		return Vector2(-1, -1)

	var lx := gx - win_at.x
	var ly := gy - win_at.y
	if lx < 0.0 or ly < 0.0 or lx > win_size.x or ly > win_size.y:
		return Vector2(-1, -1)

	# Map to viewport coords if the window buffer size differs from compositor size.
	var vp := get_viewport().get_visible_rect().size
	if vp.x > 1.0 and vp.y > 1.0 and (absf(vp.x - win_size.x) > 1.0 or absf(vp.y - win_size.y) > 1.0):
		lx *= vp.x / win_size.x
		ly *= vp.y / win_size.y
	return Vector2(lx, ly)


func _wallpaper_window_at() -> Vector2:
	var js := _hyprctl(PackedStringArray(["-j", "clients"]))
	if js.is_empty():
		var p := DisplayServer.window_get_position()
		return Vector2(p.x, p.y)
	var data: Variant = JSON.parse_string(js)
	if typeof(data) != TYPE_ARRAY:
		var p2 := DisplayServer.window_get_position()
		return Vector2(p2.x, p2.y)
	for item in data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		if str(d.get("class", "")) != WINDOW_CLASS:
			continue
		var at: Variant = d.get("at", null)
		if typeof(at) == TYPE_ARRAY and (at as Array).size() >= 2:
			return Vector2(float(at[0]), float(at[1]))
	var p3 := DisplayServer.window_get_position()
	return Vector2(p3.x, p3.y)


func _wallpaper_window_size() -> Vector2:
	var js := _hyprctl(PackedStringArray(["-j", "clients"]))
	if not js.is_empty():
		var data: Variant = JSON.parse_string(js)
		if typeof(data) == TYPE_ARRAY:
			for item in data:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				var d: Dictionary = item
				if str(d.get("class", "")) != WINDOW_CLASS:
					continue
				var sz: Variant = d.get("size", null)
				if typeof(sz) == TYPE_ARRAY and (sz as Array).size() >= 2:
					return Vector2(float(sz[0]), float(sz[1]))
	var s := DisplayServer.window_get_size()
	return Vector2(s.x, s.y)


func _project_body(node: Node3D) -> Dictionary:
	if _cam == null or node == null:
		return {"visible": false, "x": 0.0, "y": 0.0, "r_px": 0.0}
	var origin := node.global_position
	if _cam.is_position_behind(origin):
		return {"visible": false, "x": 0.0, "y": 0.0, "r_px": 0.0}
	var screen: Vector2 = _cam.unproject_position(origin)
	var radius_m := _estimate_radius_m(node)
	var edge := origin + _cam.global_transform.basis.x.normalized() * radius_m
	var edge_screen: Vector2 = _cam.unproject_position(edge)
	var r_px := screen.distance_to(edge_screen)
	var vp := get_viewport().get_visible_rect().size
	var visible := node.visible and screen.x >= -r_px and screen.y >= -r_px and screen.x <= vp.x + r_px and screen.y <= vp.y + r_px
	return {"visible": visible, "x": screen.x, "y": screen.y, "r_px": maxf(r_px, 8.0)}


func _estimate_radius_m(node: Node3D) -> float:
	return _estimate_radius_m_skip(node, PackedStringArray())


func _estimate_radius_m_skip(node: Node3D, skip: PackedStringArray) -> float:
	var merged: Variant = _merge_mesh_aabb(node, skip)
	if merged == null:
		return 200.0
	var size: Vector3 = (merged as AABB).size
	return maxf(size.x, maxf(size.y, size.z)) * 0.5


func _merge_mesh_aabb(node: Node, skip: PackedStringArray) -> Variant:
	var nm := String(node.name)
	for s in skip:
		if nm == s:
			return null
	var merged: Variant = null
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			merged = mi.global_transform * mi.mesh.get_aabb()
	for c in node.get_children():
		var child_aabb: Variant = _merge_mesh_aabb(c, skip)
		if child_aabb == null:
			continue
		merged = child_aabb if merged == null else (merged as AABB).merge(child_aabb as AABB)
	return merged


## Planet disc radius in world units (Body mesh only — moons / OPC excluded).
func _planet_visual_radius_m(body_id: String, orbit_root: Node3D) -> float:
	if body_id == "hourglass_twins":
		# Encompass both twins (and sand) from the barycenter.
		var farthest := 0.0
		for child_name in ["AshTwin", "EmberTwin"]:
			var twin := orbit_root.find_child(child_name, false, false) as Node3D
			if twin == null:
				continue
			var body := twin.find_child("Body", false, false) as Node3D
			var target: Node3D = body if body else twin
			var local_r := _estimate_radius_m(target)
			var dist := orbit_root.global_position.distance_to(target.global_position)
			farthest = maxf(farthest, dist + local_r)
		# Sand spheres live under the twin orbits.
		for sand in MeshLoader._collect_mesh_instances(orbit_root):
			if String(sand.name) != "SandSphere" or sand.mesh == null:
				continue
			var a: AABB = sand.global_transform * sand.mesh.get_aabb()
			var ext := a.size.length() * 0.5
			var dist2 := orbit_root.global_position.distance_to(a.get_center())
			farthest = maxf(farthest, dist2 + ext)
		return maxf(farthest, 80.0)
	var body := orbit_root.find_child("Body", false, false) as Node3D
	if body:
		return maxf(_estimate_radius_m_skip(body, RING_SKIP_SUBTREES), 40.0)
	return maxf(_estimate_radius_m_skip(orbit_root, RING_SKIP_SUBTREES), 40.0)


func _host_moon_envelope(body_id: String, orbit_root: Node3D) -> float:
	var pivot_name := ""
	if body_id == "timber_hearth":
		pivot_name = "Moon_Pivot"
	elif body_id == "brittle_hollow":
		pivot_name = "VolcanicMoon_Pivot"
	else:
		return 0.0
	var pivots: Array[Node3D] = []
	MeshLoader.collect_named(orbit_root, pivot_name, pivots)
	var reach := 0.0
	for pivot in pivots:
		if is_instance_valid(pivot):
			reach = maxf(reach, MeshLoader.radial_reach_xz(orbit_root.global_position, pivot))
	if reach <= 1.0:
		return 0.0
	var qm := _body_roots.get("quantum_moon") as Node3D
	var qm_r := MeshLoader.radial_reach_xz(qm.global_position, qm) if qm else 200.0
	# QM center sits one radius past the moon. The ring sits past the QM as well.
	return reach + qm_r * 2.0 + 220.0


func _project_world_radius_px(origin: Vector3, world_r: float) -> float:
	if _cam == null or world_r <= 0.0:
		return 8.0
	var edge := origin + _cam.global_transform.basis.x.normalized() * world_r
	return maxf(_cam.unproject_position(origin).distance_to(_cam.unproject_position(edge)), 8.0)


func _ring_for_body(body_id: String, bodies: Dictionary) -> Dictionary:
	var info: Dictionary = bodies.get(body_id, {})
	if not info.get("visible", false) or _cam == null:
		return {}
	var node: Node3D = _body_roots.get(body_id) as Node3D
	if node == null:
		return {}
	var cx := float(info.get("x", 0.0))
	var cy := float(info.get("y", 0.0))
	var origin := node.global_position
	var planet_r := _planet_visual_radius_m(body_id, node)
	var limb_px := _project_world_radius_px(origin, planet_r)
	# Ring tracks planet disc size directly (screen-space), so small planets stay small.
	var scale := BODY_RING_RADIUS_SCALE
	if body_id == "hourglass_twins":
		scale *= TWINS_RING_SCALE
	var r_px := limb_px * scale
	var moon_envelope := _host_moon_envelope(body_id, node)
	if moon_envelope > 0.0:
		r_px = maxf(r_px, _project_world_radius_px(origin, moon_envelope))
	if body_id == "giants_deep":
		var opc_node: Node3D = _body_roots.get("opc") as Node3D
		if opc_node:
			var opc_world := node.global_position.distance_to(opc_node.global_position) * GD_RING_OPC_SCALE
			r_px = maxf(r_px, _project_world_radius_px(origin, opc_world))
	return {
		"x": cx,
		"y": cy,
		"r_px": maxf(r_px, limb_px * (1.15 if body_id == "hourglass_twins" else 1.2)),
		# Match isometric elevation (~35°) foreshortening of the XZ orbit plane.
		"tilt": 0.55,
		"visible": true,
		"body": body_id,
	}


func _export_solar() -> void:
	if _solar_path.is_empty():
		return
	var bodies := {}
	for id in ["sun", "hourglass_twins", "timber_hearth", "brittle_hollow", "giants_deep", "dark_bramble", "quantum_moon", "opc"]:
		var node: Node3D = _body_roots.get(id) as Node3D
		if node == null:
			continue
		var info := _project_body(node)
		bodies[id] = info
	var rings := {}
	for id in RING_BODY_IDS:
		var ring := _ring_for_body(id, bodies)
		if not ring.is_empty():
			rings[id] = ring
	var gd_ring: Dictionary = rings.get("giants_deep", {})
	var payload := {
		"t": Time.get_ticks_msec() / 1000.0,
		"paused": WallpaperBus.paused,
		"cava_hold": _cam != null and _cam.has_method("is_transitioning") and bool(_cam.call("is_transitioning")),
		"qm_host": WallpaperBus.qm_host,
		"time_scale": WallpaperBus.time_scale,
		"hover": _hover_pause,
		"hover_body": _hover_body,
		"overlay": _overlay_pause,
		"control_pause": _control_pause,
		"game_pause": _game_pause,
		"supernova_active": WallpaperBus.supernova_active,
		"orbit_body": _orbit_body_id,
		"orbit_arrived": _orbit_settled,
		"video_ready": _video_ready,
		"cursor": {"x": _last_cursor_local.x, "y": _last_cursor_local.y},
		"win_at": {"x": _last_win_at.x, "y": _last_win_at.y},
		"bodies": bodies,
		"rings": rings,
		# Compat for older shell builds.
		"giants_deep_ring": gd_ring,
	}
	var json := JSON.stringify(payload)
	var tmp := _solar_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(json)
	f.close()
	DirAccess.rename_absolute(tmp, _solar_path)
