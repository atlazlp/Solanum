class_name SupernovaFx
extends Node3D

## Wallpaper approximaton of OW SunController + SupernovaEffectController:
## collapse (~10s) → expanding wall (Unity curve ~0→50k over ~10s) → engulf camera → fade → reset.

enum Phase { IDLE, COLLAPSE, EXPAND, FADE_OUT, HOLD_BLACK, FADE_IN }

const COLLAPSE_LEN := 8.0
const COLLAPSED_SCALE := 0.1
const SHOCKWAVE_LEN := 5.0
const WALL_GROW_LEN := 12.0
## Unity _supernovaScale ends near 50000; camera sits ~50k away.
const WALL_END_RADIUS := 52000.0
const FADE_OUT_LEN := 1.5
const HOLD_BLACK_LEN := 0.35
const FADE_IN_LEN := 1.55

var _phase: Phase = Phase.IDLE
var _t: float = 0.0
var _sun: Node3D
var _sun_body: Node3D
var _sun_light: Light3D
var _sun_fill: Light3D
var _sun_body_base_scale: Vector3 = Vector3.ONE
var _sun_light_energy: float = 13.0
var _sun_fill_energy: float = 0.2
var _sun_surface: MeshInstance3D
var _sun_emission_energy: float = 26.0
var _sun_albedo: Color = Color(1.0, 0.52, 0.14)
var _wall: MeshInstance3D
var _shock: MeshInstance3D
var _flash: OmniLight3D
var _fade: ColorRect
var _wall_radius: float = 0.0
var _mat_wall: ShaderMaterial
var _mat_shock: ShaderMaterial
## Blue motes that leave the white hole once the wall reaches Brittle Hollow.
const WH_MOTE_COUNT := 22
const WH_MOTE_TRAVEL_MIN := 240.0
const WH_MOTE_TRAVEL_MAX := 560.0
const WH_MOTE_BURST_LEN := 4.0
const BH_TOUCH_MARGIN := 500.0
var _bh_burst_done: bool = false
var _wh_motes: Array[Dictionary] = []
var _mote_mesh: SphereMesh
var _mote_mat: StandardMaterial3D


func setup(sun_root: Node3D, fade_layer: CanvasLayer) -> void:
	_sun = sun_root
	_sun_body = sun_root.get_node_or_null("Body") as Node3D
	_sun_light = sun_root.get_node_or_null("SunLight") as Light3D
	_sun_fill = sun_root.get_node_or_null("SunFill") as Light3D
	if _sun_body:
		_sun_body_base_scale = _sun_body.scale
	if _sun_light:
		_sun_light_energy = _sun_light.light_energy
	if _sun_fill:
		_sun_fill_energy = _sun_fill.light_energy
	if _sun_body:
		_sun_surface = _sun_body.get_node_or_null("SunSurface") as MeshInstance3D
		var sun_mat := _sun_surface.material_override as StandardMaterial3D if _sun_surface != null else null
		if sun_mat:
			_sun_emission_energy = sun_mat.emission_energy_multiplier
			_sun_albedo = sun_mat.albedo_color
	_build_meshes()
	_build_fade(fade_layer)
	WallpaperBus.supernova_requested.connect(_on_requested)
	set_process(true)


func _build_meshes() -> void:
	## Destroying wall = solid HDR shell + 1D blue→white ramp (Terrain_SUN_Supernova).
	## TendrilGlow was the “giant swirling PNG with red lines” — do not UV-map it.
	_mat_wall = ShaderMaterial.new()
	_mat_wall.shader = load("res://shaders/supernova_wall.gdshader") as Shader
	var ramp: Texture2D = load("res://assets/textures/Effects_SUN_Supernova_d.png") as Texture2D
	if ramp:
		_mat_wall.set_shader_parameter("color_ramp", ramp)
	_mat_wall.set_shader_parameter("emission_energy", 30.0)
	_mat_wall.set_shader_parameter("fresnel_power", 2.8)
	_mat_wall.set_shader_parameter("core_tint", Color(1.25, 1.35, 1.55))
	_mat_wall.set_shader_parameter("rim_tint", Color(0.35, 0.75, 1.55))

	_wall = MeshInstance3D.new()
	_wall.name = "SupernovaWall"
	var wall_mesh := SphereMesh.new()
	wall_mesh.radius = 1.0
	wall_mesh.height = 2.0
	wall_mesh.radial_segments = 96
	wall_mesh.rings = 48
	_wall.mesh = wall_mesh
	_wall.material_override = _mat_wall
	_wall.visible = false
	add_child(_wall)

	# Effects_SUN_SupernovaShockwave_mat _Color ≈ (1.05, 1.01, 2.44)
	_mat_shock = ShaderMaterial.new()
	_mat_shock.shader = load("res://shaders/supernova_shock.gdshader") as Shader
	_mat_shock.set_shader_parameter("albedo_color", Color(0.85, 0.95, 1.55, 0.55))
	_mat_shock.set_shader_parameter("emission_color", Color(0.45, 0.85, 1.8))
	_mat_shock.set_shader_parameter("emission_energy", 16.0)
	var shock_tex: Texture2D = load("res://assets/textures/Effects_SUN_Shockwave_d.png") as Texture2D
	if shock_tex:
		_mat_shock.set_shader_parameter("albedo_tex", shock_tex)

	_shock = MeshInstance3D.new()
	_shock.name = "SupernovaShockwave"
	var shock_mesh := SphereMesh.new()
	shock_mesh.radius = 1.0
	shock_mesh.height = 2.0
	shock_mesh.radial_segments = 80
	shock_mesh.rings = 40
	_shock.mesh = shock_mesh
	_shock.material_override = _mat_shock
	_shock.visible = false
	add_child(_shock)

	_flash = OmniLight3D.new()
	_flash.name = "SupernovaFlash"
	_flash.light_color = Color(0.65, 0.85, 1.0)
	_flash.light_energy = 0.0
	_flash.omni_range = 120000.0
	_flash.omni_attenuation = 0.35
	add_child(_flash)


func _build_fade(layer: CanvasLayer) -> void:
	# DebugHud is hidden in wallpaper mode, so the fade cannot live on that layer.
	var host_parent: Node = layer.get_parent() if layer != null else get_parent()
	var host := CanvasLayer.new()
	host.name = "SupernovaFadeLayer"
	host.layer = 80
	host_parent.add_child(host)
	_fade = ColorRect.new()
	_fade.name = "SupernovaFade"
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(_fade)


func _on_requested() -> void:
	if _phase != Phase.IDLE:
		return
	if WallpaperBus.mode != WallpaperBus.MODE_SOLAR:
		WallpaperBus.set_mode(WallpaperBus.MODE_SOLAR)
	var solar := get_parent()
	if solar and solar.has_method("cancel_reveal_wave"):
		solar.cancel_reveal_wave()
	WallpaperBus.supernova_active = true
	_phase = Phase.COLLAPSE
	_t = 0.0
	_wall_radius = 0.0
	_bh_burst_done = false
	_clear_wh_motes()
	_wall.visible = false
	_shock.visible = false
	_flash.light_energy = 0.0
	if _fade:
		_fade.color.a = 0.0


func _process(delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	# Keep the spectacle on wall-clock time (ignore pause / time_scale).
	_t += delta
	match _phase:
		Phase.COLLAPSE:
			_tick_collapse()
		Phase.EXPAND:
			_tick_expand()
		Phase.FADE_OUT:
			_tick_fade_out()
		Phase.HOLD_BLACK:
			_tick_hold_black()
		Phase.FADE_IN:
			_tick_fade_in()
	if _phase == Phase.EXPAND or _phase == Phase.FADE_OUT:
		_tick_wh_motes(delta)


func _tick_collapse() -> void:
	var u := clampf(_t / COLLAPSE_LEN, 0.0, 1.0)
	var ease := u * u
	var s := lerpf(1.0, COLLAPSED_SCALE, ease)
	if _sun_body:
		_sun_body.scale = _sun_body_base_scale * s
	if _sun_light:
		_sun_light.light_energy = lerpf(_sun_light_energy, 0.05, ease)
		# Collapse stays solar-hot; blast itself is the blue-white wall.
		_sun_light.light_color = Color(1.0, 0.35, 0.08).lerp(Color(0.85, 0.95, 1.0), ease)
	if _sun_fill:
		_sun_fill.light_energy = lerpf(_sun_fill_energy, 0.0, ease)
	# Bright blue-white flash near the end of collapse.
	if u > 0.85:
		_flash.light_energy = lerpf(0.0, 50.0, (u - 0.85) / 0.15)
		_flash.light_color = Color(0.7, 0.9, 1.0)
	if u >= 1.0:
		_phase = Phase.EXPAND
		_t = 0.0
		_wall.visible = true
		_shock.visible = true
		_wall_radius = 50.0
		_set_sphere_radius(_wall, _wall_radius)
		_set_sphere_radius(_shock, 80.0)
		if _sun_body:
			_sun_body.visible = false
		_flash.light_energy = 70.0
		_flash.light_color = Color(0.75, 0.92, 1.0)
		_mat_wall.set_shader_parameter("emission_energy", 34.0)
		_mat_wall.set_shader_parameter("core_tint", Color(1.3, 1.4, 1.6))
		_mat_wall.set_shader_parameter("rim_tint", Color(0.3, 0.7, 1.6))


func _tick_expand() -> void:
	# Shockwave: Unity Linear(0→1 over 5s) → scale 0→100000 (we cap visually).
	var shock_u := clampf(_t / SHOCKWAVE_LEN, 0.0, 1.0)
	var shock_r := lerpf(100.0, 90000.0, shock_u * shock_u)
	_set_sphere_radius(_shock, shock_r)
	var shock_col := Color(0.85, 0.95, 1.55, lerpf(0.7, 0.0, shock_u))
	_mat_shock.set_shader_parameter("albedo_color", shock_col)
	_shock.visible = shock_u < 1.0 and shock_col.a > 0.02

	# Wall: Unity roughly Linear(5→15s, 0→50000); we grow from collapse end.
	var wall_u := clampf(_t / WALL_GROW_LEN, 0.0, 1.0)
	# Ease-in so it starts slow then races outward (reads more like the game wall).
	var wall_ease := wall_u * wall_u
	_wall_radius = lerpf(80.0, WALL_END_RADIUS, wall_ease)
	_set_sphere_radius(_wall, _wall_radius)
	var cool := smoothstep(0.1, 0.9, wall_u)
	_mat_wall.set_shader_parameter("emission_energy", lerpf(36.0, 24.0, cool))
	_mat_wall.set_shader_parameter(
		"core_tint",
		Color(1.15, 1.3, 1.6).lerp(Color(1.4, 1.45, 1.55), cool)
	)
	_flash.light_energy = lerpf(70.0, 18.0, wall_u)
	_flash.light_color = Color(0.7, 0.9, 1.0).lerp(Color(0.9, 0.95, 1.0), cool)
	_maybe_spawn_wh_motes()

	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var cam_dist := 50000.0
	if cam:
		cam_dist = cam.global_position.length()
	# Engulf when the wall reaches the camera (with a small margin).
	if _wall_radius >= cam_dist * 0.92 or wall_u >= 1.0:
		_phase = Phase.FADE_OUT
		_t = 0.0


func _tick_fade_out() -> void:
	var u := clampf(_t / FADE_OUT_LEN, 0.0, 1.0)
	if _fade:
		_fade.color = Color(0, 0, 0, u)
	_flash.light_energy = lerpf(_flash.light_energy, 0.0, u)
	if u >= 1.0:
		_reset_visuals_hidden()
		var solar := get_parent()
		if solar and solar.has_method("park_reveal_wave"):
			solar.park_reveal_wave()
		_phase = Phase.HOLD_BLACK
		_t = 0.0


func _tick_hold_black() -> void:
	if _t >= HOLD_BLACK_LEN:
		_phase = Phase.FADE_IN
		_t = 0.0


func _tick_fade_in() -> void:
	var u := clampf(_t / FADE_IN_LEN, 0.0, 1.0)
	if _fade:
		_fade.color = Color(0, 0, 0, 1.0 - u)
	# Stars come back with the overlay. The sun stays dark, then blooms in.
	_apply_sun_fade(smoothstep(0.22, 1.0, u))
	if u >= 1.0:
		if _fade:
			_fade.color = Color(0, 0, 0, 0)
		_apply_sun_fade(1.0)
		_phase = Phase.IDLE
		WallpaperBus.supernova_active = false
		var solar := get_parent()
		if solar and solar.has_method("play_reveal_wave"):
			solar.play_reveal_wave()


func _reset_visuals_hidden() -> void:
	_wall.visible = false
	_shock.visible = false
	_flash.light_energy = 0.0
	_wall_radius = 0.0
	_clear_wh_motes()
	if _sun_light:
		_sun_light.light_color = Color(1.0, 0.55, 0.18)
	_apply_sun_fade(0.0)


func _apply_sun_fade(amount: float) -> void:
	var e := clampf(amount, 0.0, 1.0)
	if _sun_body:
		_sun_body.visible = true
		_sun_body.scale = _sun_body_base_scale * lerpf(0.28, 1.0, e)
	var mat := _sun_surface.material_override as StandardMaterial3D if _sun_surface != null else null
	if mat:
		var alb := _sun_albedo
		alb.a = 1.0
		if e < 0.999:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			alb.a = e
		else:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color = alb
		mat.emission_energy_multiplier = _sun_emission_energy * e
	if _sun_light:
		_sun_light.light_energy = _sun_light_energy * e
	if _sun_fill:
		_sun_fill.light_energy = _sun_fill_energy * e


func _set_sphere_radius(mi: MeshInstance3D, radius: float) -> void:
	if mi == null:
		return
	mi.scale = Vector3.ONE * maxf(radius, 0.01)


func _maybe_spawn_wh_motes() -> void:
	if _bh_burst_done:
		return
	var solar := get_parent()
	if solar == null:
		return
	var bh := solar.find_child("OrbitRoot_BH", true, false) as Node3D
	if bh == null:
		return
	if _wall_radius < bh.global_position.length() - BH_TOUCH_MARGIN:
		return
	_bh_burst_done = true
	var wh := solar.find_child("WhiteHole", true, false) as Node3D
	if wh == null:
		return
	_spawn_wh_motes(wh.global_position)


func _spawn_wh_motes(origin: Vector3) -> void:
	_ensure_mote_resources()
	var outward := origin.normalized()
	if outward.length_squared() < 0.001:
		outward = Vector3.LEFT
	for _i in WH_MOTE_COUNT:
		var mi := MeshInstance3D.new()
		mi.name = "WhiteHoleMote"
		mi.mesh = _mote_mesh
		mi.material_override = _mote_mat
		mi.scale = Vector3.ONE * randf_range(0.45, 1.0)
		add_child(mi)
		mi.global_position = origin
		var scatter := Vector3(
			randf_range(-1.15, 1.15),
			randf_range(-0.85, 0.85),
			randf_range(-1.15, 1.15)
		)
		_wh_motes.append({
			"node": mi,
			"origin": origin,
			"dir": (outward * 0.55 + scatter).normalized(),
			"travel": randf_range(WH_MOTE_TRAVEL_MIN, WH_MOTE_TRAVEL_MAX),
			"age": 0.0,
		})


func _ensure_mote_resources() -> void:
	if _mote_mesh == null:
		_mote_mesh = SphereMesh.new()
		_mote_mesh.radius = 28.0
		_mote_mesh.height = 56.0
		_mote_mesh.radial_segments = 8
		_mote_mesh.rings = 4
	if _mote_mat == null:
		_mote_mat = StandardMaterial3D.new()
		_mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mote_mat.albedo_color = Color(0.92, 0.97, 1.2)
		_mote_mat.emission_enabled = true
		_mote_mat.emission = Color(1.25, 1.42, 1.75)
		_mote_mat.emission_energy_multiplier = 62.0


func _tick_wh_motes(delta: float) -> void:
	var i := 0
	while i < _wh_motes.size():
		var mote: Dictionary = _wh_motes[i]
		var n: Node3D = mote["node"]
		if n == null or not is_instance_valid(n):
			_wh_motes.remove_at(i)
			continue
		mote["age"] = float(mote["age"]) + delta
		var u := clampf(float(mote["age"]) / WH_MOTE_BURST_LEN, 0.0, 1.0)
		var ease := 1.0 - pow(1.0 - u, 3.0)
		var pos: Vector3 = (mote["origin"] as Vector3) + (mote["dir"] as Vector3) * float(mote["travel"]) * ease
		n.global_position = pos
		if pos.length() <= _wall_radius:
			n.queue_free()
			_wh_motes.remove_at(i)
			continue
		i += 1


func _clear_wh_motes() -> void:
	for mote in _wh_motes:
		var n: Node = mote.get("node") as Node
		if n != null and is_instance_valid(n):
			n.queue_free()
	_wh_motes.clear()
