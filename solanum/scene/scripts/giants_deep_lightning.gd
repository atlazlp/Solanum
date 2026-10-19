class_name GiantsDeepLightning
extends Node3D

## Soft circular storm flashes just under the GD cloud tops.

@export var flash_count: int = 5
@export var cloud_radius: float = 880.0
@export var interval_min: float = 2.8
@export var interval_max: float = 7.5

var _flashes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## Orbit view paints the flash into the cloud shader. Satellite keeps the white discs.
var _orbit_detail: bool = false
var _cloud_mat: ShaderMaterial
## Just under the 950 m shell. A short reach keeps the flash a patch in the cloud.
const ORBIT_STORM_RADIUS := 900.0


func _ready() -> void:
	_rng.seed = 77
	for i in flash_count:
		var root := Node3D.new()
		root.name = "Storm_%d" % i
		root.visible = false
		var core := _make_disc(38.0, Color(1.0, 1.0, 1.0, 0.55), 40.0)
		var mid := _make_disc(75.0, Color(0.85, 0.95, 1.0, 0.2), 16.0)
		var outer := _make_disc(120.0, Color(0.7, 0.88, 1.0, 0.07), 7.0)
		root.add_child(outer)
		root.add_child(mid)
		root.add_child(core)
		var light := OmniLight3D.new()
		light.light_color = Color(0.85, 0.95, 1.0)
		light.light_energy = 0.0
		light.omni_range = 650.0
		root.add_child(light)
		add_child(root)
		_flashes.append({
			"root": root,
			"core": core,
			"mid": mid,
			"outer": outer,
			"light": light,
			"timer": _rng.randf_range(0.5, interval_max),
			"life": 0.0,
			"dur": 1.0,
			"blink": false,
			"peak_core_a": 0.55,
			"peak_mid_a": 0.2,
			"peak_outer_a": 0.07,
			"peak_core_e": 40.0,
			"peak_mid_e": 16.0,
			"peak_outer_e": 7.0,
			"peak_light": 14.0,
			"branches": [],
		})


func set_orbit_detail(enabled: bool) -> void:
	if _orbit_detail == enabled:
		return
	_orbit_detail = enabled
	for flash in _flashes:
		var root: Node3D = flash["root"]
		var light: OmniLight3D = flash["light"]
		root.visible = false
		light.light_energy = 0.0
		flash["life"] = 0.0
		flash["glow"] = 0.0
		flash["timer"] = _rng.randf_range(1.6, 4.5) if enabled else _rng.randf_range(interval_min, interval_max)
		_hide_branches(flash)
		_hide_volume(flash)
		if not enabled:
			_paint_satellite(flash)
	_sync_cloud()


func set_cloud_material(mat: ShaderMaterial) -> void:
	_cloud_mat = mat
	_sync_cloud()


func _make_disc(radius: float, color: Color, emission: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 5.0
	cyl.radial_segments = 24
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.97, 1.0)
	mat.emission_energy_multiplier = emission
	mat.no_depth_test = true
	mat.render_priority = 2
	mi.material_override = mat
	return mi


func _paint_disc(mi: MeshInstance3D, albedo: Color, emission: Color, depth_test: bool) -> void:
	var mat := mi.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = albedo
	mat.emission = emission
	mat.no_depth_test = not depth_test


func _paint_satellite(flash: Dictionary) -> void:
	_paint_disc(flash["core"], Color(1.0, 1.0, 1.0, 0.55), Color(0.9, 0.97, 1.0), false)
	_paint_disc(flash["mid"], Color(0.85, 0.95, 1.0, 0.2), Color(0.9, 0.97, 1.0), false)
	_paint_disc(flash["outer"], Color(0.7, 0.88, 1.0, 0.07), Color(0.9, 0.97, 1.0), false)
	var light: OmniLight3D = flash["light"]
	light.light_color = Color(0.85, 0.95, 1.0)


func _paint_orbit(flash: Dictionary) -> void:
	## Unity CloudLightningGenerator: red-pink through pink, drawn on the shell.
	_paint_disc(flash["core"], Color(1.0, 0.42, 0.38, 0.72), Color(1.0, 0.35, 0.30), true)
	_paint_disc(flash["mid"], Color(0.78, 0.22, 0.24, 0.28), Color(0.9, 0.25, 0.28), true)
	_paint_disc(flash["outer"], Color(1.0, 0.50, 0.55, 0.12), Color(1.0, 0.45, 0.50), true)
	var light: OmniLight3D = flash["light"]
	light.light_color = Color(1.0, 0.42, 0.40)
	for branch in flash["branches"]:
		var mi: MeshInstance3D = branch["mi"]
		_paint_disc(mi, Color(1.0, 0.48, 0.46, 0.5), Color(1.0, 0.38, 0.34), true)


func _ensure_branches(flash: Dictionary) -> void:
	if not (flash["branches"] as Array).is_empty():
		return
	var root: Node3D = flash["root"]
	var branches: Array = []
	for i in 6:
		var mi := _make_disc(32.0, Color(1.0, 0.48, 0.46, 0.5), 14.0)
		mi.name = "Branch_%d" % i
		mi.visible = false
		root.add_child(mi)
		branches.append({"mi": mi, "delay": 0.0})
	flash["branches"] = branches


func _hide_branches(flash: Dictionary) -> void:
	for branch in flash["branches"]:
		var mi: MeshInstance3D = branch["mi"]
		mi.visible = false


func _process(delta: float) -> void:
	if WallpaperBus.blocks_motion() or WallpaperBus.mode != WallpaperBus.MODE_SOLAR:
		return
	var dt := delta * WallpaperBus.motion_scale()
	for flash in _flashes:
		var root: Node3D = flash["root"]
		var light: OmniLight3D = flash["light"]
		if root.visible:
			flash["life"] = float(flash["life"]) + dt
			var dur: float = flash["dur"]
			var t := clampf(float(flash["life"]) / dur, 0.0, 1.0)
			# Soft envelope: ease in, hold, fade out.
			var env := 1.0
			if t < 0.12:
				env = t / 0.12
			elif t > 0.55:
				env = 1.0 - (t - 0.55) / 0.45
			env = clampf(env, 0.0, 1.0)
			env = env * env * (3.0 - 2.0 * env)

			# Optional end blinks while fading out.
			var blink_mul := 1.0
			if flash["blink"] and t > 0.58:
				var phase := (t - 0.58) / 0.42
				var flicker := absf(sin(float(flash["life"]) * 7.0))
				var gate := 1.0 if fmod(phase * 2.4, 1.0) < 0.62 else 0.08
				blink_mul = gate * (0.35 + 0.65 * flicker)

			var u := env * blink_mul
			if _orbit_detail:
				u = _orbit_flicker(t, float(flash["life"]))
				flash["glow"] = u
				_show_discs(flash, false)
				_hide_volume(flash)
				light.light_energy = 0.0
			else:
				flash["glow"] = 0.0
				_set_disc_fade(flash["core"], float(flash["peak_core_a"]) * u, float(flash["peak_core_e"]) * u)
				_set_disc_fade(flash["mid"], float(flash["peak_mid_a"]) * u, float(flash["peak_mid_e"]) * u)
				_set_disc_fade(flash["outer"], float(flash["peak_outer_a"]) * u, float(flash["peak_outer_e"]) * u)
				light.light_energy = float(flash["peak_light"]) * u
			if t >= 1.0:
				root.visible = false
				light.light_energy = 0.0
				flash["glow"] = 0.0
				_hide_branches(flash)
				_hide_volume(flash)
				if _orbit_detail:
					flash["timer"] = _rng.randf_range(4.0, 8.0)
				else:
					flash["timer"] = _rng.randf_range(interval_min, interval_max)
		else:
			flash["timer"] = float(flash["timer"]) - dt
			if float(flash["timer"]) <= 0.0:
				_spawn_flash(flash)
	if _orbit_detail:
		_sync_cloud()


func _set_disc_fade(mi: MeshInstance3D, alpha: float, emission: float) -> void:
	var mat := mi.material_override as StandardMaterial3D
	mat.albedo_color.a = alpha
	mat.emission_energy_multiplier = emission


func _orbit_flicker(t: float, life: float) -> float:
	var env := 1.0
	if t < 0.08:
		env = t / 0.08
	elif t > 0.78:
		env = 1.0 - (t - 0.78) / 0.22
	env = clampf(env, 0.0, 1.0)
	var flicker := 0.62 + 0.38 * absf(sin(life * 4.2))
	if fmod(life * 0.85, 1.0) > 0.86:
		flicker *= 0.18
	return clampf(env * flicker, 0.0, 1.0)


func _fade_branches(flash: Dictionary, life: float, dur: float) -> void:
	for branch in flash["branches"]:
		var mi: MeshInstance3D = branch["mi"]
		var delay := float(branch["delay"])
		var local := life - delay
		if local <= 0.0 or local >= dur:
			mi.visible = false
			continue
		mi.visible = true
		var t := clampf(local / dur, 0.0, 1.0)
		var u := _orbit_flicker(t, local)
		_set_disc_fade(mi, 0.5 * u, 14.0 * u)


func _make_glow(radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 8
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.albedo_color = Color(1.0, 0.42, 0.4, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.32)
	mat.emission_energy_multiplier = 0.0
	mat.render_priority = 1
	mi.material_override = mat
	mi.visible = false
	return mi


func _ensure_volume(flash: Dictionary) -> void:
	if flash.has("volume"):
		return
	var root: Node3D = flash["root"]
	var volume: Array = []
	for i in 5:
		var mi := _make_glow(48.0 if i > 0 else 130.0)
		mi.name = "Glow_%d" % i
		root.add_child(mi)
		volume.append(mi)
	flash["volume"] = volume


func _hide_volume(flash: Dictionary) -> void:
	if not flash.has("volume"):
		return
	for mi in flash["volume"]:
		(mi as MeshInstance3D).visible = false


func _show_discs(flash: Dictionary, shown: bool) -> void:
	(flash["core"] as MeshInstance3D).visible = shown
	(flash["mid"] as MeshInstance3D).visible = shown
	(flash["outer"] as MeshInstance3D).visible = shown


func _fade_volume(flash: Dictionary, u: float) -> void:
	_ensure_volume(flash)
	var i := 0
	for item in flash["volume"]:
		var mi := item as MeshInstance3D
		mi.visible = u > 0.02
		var fall := 1.0 if i == 0 else 0.55
		_set_disc_fade(mi, 0.55 * fall * u, (10.0 if i == 0 else 6.0) * u)
		i += 1


func _layout_volume(flash: Dictionary) -> void:
	_ensure_volume(flash)
	_show_discs(flash, false)
	var root: Node3D = flash["root"]
	var scale_x := maxf(absf(root.scale.x), 0.01)
	var i := 0
	for item in flash["volume"]:
		var mi := item as MeshInstance3D
		if i == 0:
			mi.position = Vector3.ZERO
			mi.scale = Vector3.ONE * _rng.randf_range(1.3, 2.2)
		else:
			var ang := _rng.randf() * TAU
			var dist := _rng.randf_range(24.0, 80.0) / scale_x
			var lift := _rng.randf_range(-28.0, 36.0) / scale_x
			mi.position = Vector3(cos(ang) * dist, lift, sin(ang) * dist)
			mi.scale = Vector3.ONE * _rng.randf_range(0.45, 1.15)
		mi.visible = false
		i += 1


func _layout_branches(flash: Dictionary) -> void:
	_ensure_branches(flash)
	var n := _rng.randi_range(3, 6)
	var root: Node3D = flash["root"]
	var scale_x := maxf(absf(root.scale.x), 0.01)
	for i in (flash["branches"] as Array).size():
		var branch: Dictionary = flash["branches"][i]
		var mi: MeshInstance3D = branch["mi"]
		if i >= n:
			mi.visible = false
			branch["delay"] = 99.0
			continue
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(117.0, 311.0) / scale_x
		mi.position = Vector3(cos(ang) * dist, _rng.randf_range(-4.0, 8.0), sin(ang) * dist)
		mi.scale = Vector3.ONE * _rng.randf_range(0.55, 1.15)
		branch["delay"] = _rng.randf_range(0.11, 0.73)
		mi.visible = false


func _spawn_flash(flash: Dictionary) -> void:
	var root: Node3D = flash["root"]
	var light: OmniLight3D = flash["light"]

	var theta := _rng.randf() * TAU
	var phi := _rng.randf_range(0.4, PI - 0.4)
	var radial := Vector3(sin(phi) * cos(theta), cos(phi) * 0.55, sin(phi) * sin(theta)).normalized()
	if _orbit_detail:
		root.position = radial * ORBIT_STORM_RADIUS * _rng.randf_range(0.94, 1.04)
	else:
		root.position = radial * (cloud_radius * _rng.randf_range(0.91, 0.96))

	var tangent := Vector3.UP.cross(radial)
	if tangent.length_squared() < 0.001:
		tangent = Vector3.RIGHT.cross(radial)
	tangent = tangent.normalized()
	var bitangent := radial.cross(tangent).normalized()
	root.basis = Basis(tangent, radial, bitangent).orthonormalized()

	var s := _rng.randf_range(0.85, 1.25) if _orbit_detail else _rng.randf_range(0.65, 1.05)
	root.scale = Vector3(s, 1.0, s)

	if _orbit_detail:
		_hide_branches(flash)
		_hide_volume(flash)
		_show_discs(flash, false)
		flash["blink"] = false
		flash["peak_core_a"] = _rng.randf_range(0.55, 0.78)
		flash["peak_mid_a"] = _rng.randf_range(0.18, 0.32)
		flash["peak_outer_a"] = _rng.randf_range(0.08, 0.14)
		flash["peak_core_e"] = _rng.randf_range(22.0, 36.0)
		flash["peak_mid_e"] = _rng.randf_range(8.0, 14.0)
		flash["peak_outer_e"] = _rng.randf_range(3.0, 7.0)
		flash["peak_light"] = _rng.randf_range(3.0, 7.0)
	else:
		_paint_satellite(flash)
		_hide_branches(flash)
		_hide_volume(flash)
		_show_discs(flash, true)
		flash["blink"] = _rng.randf() < 0.45
		flash["peak_core_a"] = _rng.randf_range(0.4, 0.6)
		flash["peak_mid_a"] = _rng.randf_range(0.12, 0.22)
		flash["peak_outer_a"] = _rng.randf_range(0.04, 0.09)
		flash["peak_core_e"] = _rng.randf_range(28.0, 48.0)
		flash["peak_mid_e"] = _rng.randf_range(10.0, 18.0)
		flash["peak_outer_e"] = _rng.randf_range(4.0, 9.0)
		flash["peak_light"] = _rng.randf_range(10.0, 16.0)

	_set_disc_fade(flash["core"], 0.0, 0.0)
	_set_disc_fade(flash["mid"], 0.0, 0.0)
	_set_disc_fade(flash["outer"], 0.0, 0.0)
	light.light_energy = 0.0
	flash["life"] = 0.0
	flash["glow"] = 0.0
	flash["dur"] = _rng.randf_range(3.4, 5.6) if _orbit_detail else _rng.randf_range(2.0, 3.5)
	root.visible = true


func _sync_cloud() -> void:
	if _cloud_mat == null or not is_instance_valid(_cloud_mat):
		return
	var pos := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var amt := [0.0, 0.0, 0.0, 0.0]
	var slot := 0
	if _orbit_detail:
		for flash in _flashes:
			if slot >= 4:
				break
			var root: Node3D = flash["root"]
			var g := float(flash.get("glow", 0.0))
			if not root.visible or g <= 0.001:
				continue
			pos[slot] = root.global_position
			amt[slot] = g
			slot += 1
	for i in 4:
		_cloud_mat.set_shader_parameter("flash%d" % i, pos[i])
		_cloud_mat.set_shader_parameter("amt%d" % i, amt[i])
