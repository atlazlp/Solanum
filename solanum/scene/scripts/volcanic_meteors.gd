class_name VolcanicMeteors
extends Node3D

## Random launch from Hollow's Lantern. Most fall straight-ish; some wrap around BH first.
## All paths end on Brittle Hollow's surface.
## 40% of hits transit the black hole and exit the White Hole as a separate meteor
## (lantern cycle keeps running).

@export var count: int = 6
@export var moon_radius: float = 95.0
@export var planet_hit_radius: float = 300.0
@export var speed_min: float = 70.0
@export var speed_max: float = 240.0
@export var rock_radius: float = 32.0
@export var respawn_gap_min: float = 18.0
@export var respawn_gap_max: float = 55.0
## Chance a launch is fast enough to wrap around before impact.
@export var wrap_chance: float = 0.38
## Chance a surface hit falls into BH and exits the White Hole.
@export var white_hole_chance: float = 0.40
@export var white_hole_delay: float = 1.0
## How far WH exits drift before easing to a stop (metres).
@export var white_hole_travel_min: float = 220.0
@export var white_hole_travel_max: float = 480.0
@export var white_hole_life_min: float = 40.0
@export var white_hole_life_max: float = 50.0
@export var white_hole_fade_len: float = 3.0

const METEOR_GLB := "res://assets/gltf/Meteors.glb"

var _moon: Node3D
var _planet: Node3D
var _white_hole: Node3D
var _shapes: Array[Mesh] = []
var _shape_fit: Array[float] = []
var _chunked: Dictionary = {}
var _rocks: Array[Dictionary] = []
## Independent White Hole exits — do not occupy lantern slots.
var _wh_ejects: Array[Dictionary] = []
var _orbit_mesh: bool = false
## Satellite launches are emissive spheres. Orbit launches use the game rocks.
var _close_rocks: bool = false
var _rng := RandomNumberGenerator.new()


func setup(moon_body: Node3D, planet_orbit: Node3D, white_hole: Node3D = null) -> void:
	_moon = moon_body
	_planet = planet_orbit
	_white_hole = white_hole
	_rng.randomize()
	_rebuild()


func set_white_hole(white_hole: Node3D) -> void:
	_white_hole = white_hole


## Point new launches at the lantern that is actually on screen.
## close_detail: orbit uses game meshes; satellite uses the old lava spheres.
func set_launch_moon(moon_body: Node3D, surface_radius: float = -1.0, close_detail: bool = false) -> void:
	if surface_radius > 0.0:
		moon_radius = surface_radius
	var mode_changed := close_detail != _close_rocks
	_close_rocks = close_detail
	if moon_body == null:
		return
	if moon_body == _moon and not mode_changed:
		return
	_moon = moon_body
	for rock in _rocks:
		if rock["active"]:
			_despawn(rock)
		rock["wait"] = _rng.randf_range(0.15, 1.4)
		var holder := rock["node"] as Node3D
		if holder:
			_fill_rock_visual(holder, false)


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_rocks.clear()
	_wh_ejects.clear()
	if _moon == null or _planet == null:
		return
	_load_shapes()
	for i in count:
		var holder := _make_rock_mesh("Meteor_%d" % i)
		holder.visible = false
		add_child(holder)
		_rocks.append({
			"node": holder,
			"prev_pos": Vector3.ZERO,
			"t": 0.0,
			"dur": 1.0,
			"spin": _rng.randf_range(1.0, 4.0),
			"spin_axis": _rand_unit(),
			"wait": _rng.randf_range(0.0, respawn_gap_max),
			"active": false,
			"mode": "idle",
			"p0": Vector3.ZERO,
			"p1": Vector3.ZERO,
			"p2": Vector3.ZERO,
			"p3": Vector3.ZERO,
			"r0": 0.0,
			"r1": 0.0,
			"ang0": 0.0,
			"ang1": 0.0,
			"y0": 0.0,
			"y1": 0.0,
			"prev_len": 0.0,
		})


func _load_shapes() -> void:
	if not _shapes.is_empty():
		return
	var res: Resource = load(METEOR_GLB)
	if res is PackedScene:
		var inst := (res as PackedScene).instantiate()
		_collect_shapes(inst)
		inst.queue_free()


func _collect_shapes(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh := (node as MeshInstance3D).mesh
		var extent := mesh.get_aabb().size.length() * 0.5
		if extent > 0.01:
			_shapes.append(mesh)
			_shape_fit.append(rock_radius / extent)
	for c in node.get_children():
		_collect_shapes(c)


func _lava_detail() -> Texture2D:
	var detail: Texture2D = load("res://assets/textures/LOD_Terrain_VM_RockDetail_d.png") as Texture2D
	if detail == null:
		detail = load("res://assets/textures/Terrain_VM_RockDetail_d.png") as Texture2D
	return detail


func _sphere_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.18, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(1.99, 0.15, 0.0)
	mat.emission_energy_multiplier = 40.0
	var detail := _lava_detail()
	if detail:
		mat.emission_texture = detail
	return mat


func _rock_material(for_white_hole: bool) -> Material:
	var detail := _lava_detail()
	var shader := load("res://shaders/meteor_rock.gdshader") as Shader
	if shader == null or detail == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.22, 0.04)
		mat.emission_enabled = true
		mat.emission = Color(1.99, 0.22, 0.02)
		mat.emission_energy_multiplier = 36.0
		if for_white_hole:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return mat
	var sm := ShaderMaterial.new()
	sm.shader = shader
	sm.set_shader_parameter("fade", 1.0)
	return sm


func _make_rock_mesh(mesh_name: String, for_white_hole: bool = false) -> Node3D:
	var holder := Node3D.new()
	holder.name = mesh_name
	_fill_rock_visual(holder, for_white_hole)
	return holder


func _fill_rock_visual(holder: Node3D, for_white_hole: bool) -> void:
	for c in holder.get_children():
		holder.remove_child(c)
		c.free()
	var mi := MeshInstance3D.new()
	mi.name = "Rock"
	if for_white_hole or _close_rocks:
		var fit := 1.0
		if _shapes.is_empty():
			var sphere := SphereMesh.new()
			sphere.radius = rock_radius
			sphere.height = rock_radius * 2.0
			mi.mesh = sphere
		else:
			var pick := _rng.randi_range(0, _shapes.size() - 1)
			var src := _shapes[pick]
			if _close_rocks and not for_white_hole:
				src = _chunk_mesh(src)
			mi.mesh = src
			fit = _shape_fit[pick] * _rng.randf_range(0.85, 1.2)
			if _close_rocks and not for_white_hole:
				fit *= 1.45
			mi.scale = Vector3.ONE * fit
			mi.rotation = Vector3(
				_rng.randf_range(0.0, TAU),
				_rng.randf_range(0.0, TAU),
				_rng.randf_range(0.0, TAU)
			)
		mi.material_override = _rock_material(for_white_hole)
	else:
		var radius := rock_radius * _rng.randf_range(0.5, 1.4)
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		mi.mesh = sphere
		mi.material_override = _sphere_material()
	holder.add_child(mi)


func _chunk_mesh(src: Mesh) -> Mesh:
	## Stretch the flat axis until the shard is about as thick as it is wide.
	if _chunked.has(src):
		return _chunked[src] as Mesh
	var arrays: Array = src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return src
	var mn := verts[0]
	var mx := verts[0]
	for v in verts:
		mn = mn.min(v)
		mx = mx.max(v)
	var ext := mx - mn
	var thin := 0
	if ext.y < ext[thin]:
		thin = 1
	if ext.z < ext[thin]:
		thin = 2
	var longest := maxf(ext.x, maxf(ext.y, ext.z))
	var thin_ext: float = ext[thin]
	if thin_ext <= 0.0001 or longest <= thin_ext * 1.05:
		_chunked[src] = src
		return src
	var boost: float = longest / thin_ext
	var center := (mn + mx) * 0.5
	var out := PackedVector3Array()
	out.resize(verts.size())
	for i in verts.size():
		var p := verts[i]
		if thin == 0:
			p.x = center.x + (p.x - center.x) * boost
		elif thin == 1:
			p.y = center.y + (p.y - center.y) * boost
		else:
			p.z = center.z + (p.z - center.z) * boost
		out[i] = p
	arrays[Mesh.ARRAY_VERTEX] = out
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_chunked[src] = mesh
	return mesh


func _rock_mi(holder: Node) -> MeshInstance3D:
	var mi := holder.get_node_or_null("Rock") as MeshInstance3D
	if mi == null and holder is MeshInstance3D:
		return holder as MeshInstance3D
	return mi


func _planet_local(global_pt: Vector3) -> Vector3:
	return _planet.to_local(global_pt)


func _rand_unit() -> Vector3:
	var v := Vector3(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	)
	if v.length_squared() < 0.001:
		return Vector3.UP
	return v.normalized()


func _arm(rock: Dictionary) -> void:
	var moon_l := _planet_local(_moon.global_position)
	var dist := maxf(moon_l.length(), 1.0)
	var wrap := _rng.randf() < wrap_chance

	if wrap:
		_arm_wrap(rock, moon_l, dist)
	else:
		_arm_fall(rock, moon_l, dist)


func _arm_fall(rock: Dictionary, moon_l: Vector3, dist: float) -> void:
	var launch_dir := _rand_unit()
	var hit_dir := _rand_unit()
	var p0: Vector3 = moon_l + launch_dir * moon_radius
	var p3: Vector3 = hit_dir * planet_hit_radius
	var mid := (p0 + p3) * 0.5
	var outward := mid.normalized() if mid.length_squared() > 0.01 else launch_dir
	var bulge := _rng.randf_range(0.12, 0.45) * dist
	var side := launch_dir.cross(hit_dir)
	if side.length_squared() < 0.001:
		side = launch_dir.cross(Vector3.UP)
	side = side.normalized() * (_rng.randf_range(-0.3, 0.3) * dist)
	var p1: Vector3 = p0 + launch_dir * (dist * _rng.randf_range(0.2, 0.5)) + side * 0.4 + outward * bulge * 0.3
	var p2: Vector3 = p3 + (-hit_dir) * (dist * _rng.randf_range(0.1, 0.3)) + side * 0.55 + outward * bulge * 0.5
	var path_len := p0.distance_to(p1) + p1.distance_to(p2) + p2.distance_to(p3)
	var speed := _rng.randf_range(speed_min, speed_max)
	rock["mode"] = "bezier"
	rock["p0"] = p0
	rock["p1"] = p1
	rock["p2"] = p2
	rock["p3"] = p3
	rock["t"] = 0.0
	rock["dur"] = maxf(path_len / speed, 3.5)
	rock["prev_len"] = p0.length()
	rock["active"] = true
	rock["node"].visible = true
	rock["node"].position = p0
	rock["prev_pos"] = p0


func _arm_wrap(rock: Dictionary, moon_l: Vector3, dist: float) -> void:
	## Hard launch: spiral around the planet for ~0.5–2 turns, then settle onto the surface.
	var launch_dir := _rand_unit()
	var p0: Vector3 = moon_l + launch_dir * moon_radius
	var ang0 := atan2(p0.z, p0.x)
	var sign := 1.0 if _rng.randf() < 0.5 else -1.0
	var turns := _rng.randf_range(0.55, 2.1)
	var hit := _rand_unit() * planet_hit_radius
	var ang_hit := atan2(hit.z, hit.x)
	# Travel `turns` in `sign` direction and land on the random surface point.
	var d := angle_difference(ang0, ang_hit)
	if sign > 0.0 and d < 0.0:
		d += TAU
	elif sign < 0.0 and d > 0.0:
		d -= TAU
	var extra := sign * maxf(turns - absf(d) / TAU, 0.0) * TAU
	var ang1 := ang0 + d + extra
	var r0 := p0.length()
	var r_peak := maxf(r0, dist) * _rng.randf_range(1.08, 1.5)
	var speed := _rng.randf_range(speed_max * 0.9, speed_max * 1.6)
	var path_len := absf(ang1 - ang0) * ((r0 + r_peak) * 0.5)
	rock["mode"] = "wrap"
	rock["p0"] = p0
	rock["p3"] = hit
	rock["ang0"] = ang0
	rock["ang1"] = ang1
	rock["r0"] = r0
	rock["r1"] = planet_hit_radius
	rock["r_peak"] = r_peak
	rock["y0"] = p0.y
	rock["y1"] = hit.y
	rock["t"] = 0.0
	rock["dur"] = maxf(path_len / speed, 6.0)
	rock["prev_len"] = r0
	rock["active"] = true
	rock["node"].visible = true
	rock["node"].position = p0
	rock["prev_pos"] = p0


func _bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return u * u * u * a + 3.0 * u * u * t * b + 3.0 * u * t * t * c + t * t * t * d


func _wrap_pos(rock: Dictionary, t: float) -> Vector3:
	var s := t * t * (3.0 - 2.0 * t)
	var ang: float = lerpf(float(rock["ang0"]), float(rock["ang1"]), s)
	var rise := sin(s * PI)
	var r: float = lerpf(float(rock["r0"]), float(rock["r1"]), s)
	r = lerpf(r, float(rock["r_peak"]), rise * 0.85)
	var y: float = lerpf(float(rock["y0"]), float(rock["y1"]), s)
	var horiz := maxf(r * r - y * y, 1.0)
	var rh := sqrt(horiz)
	var spiral := Vector3(cos(ang) * rh, y, sin(ang) * rh)
	# Ease onto the exact surface hit point for the last quarter.
	if s > 0.72:
		var u := (s - 0.72) / 0.28
		u = u * u * (3.0 - 2.0 * u)
		return spiral.lerp(rock["p3"] as Vector3, u)
	return spiral


func _despawn(rock: Dictionary) -> void:
	rock["active"] = false
	rock["mode"] = "idle"
	rock["wait"] = _rng.randf_range(respawn_gap_min, respawn_gap_max)
	rock["node"].visible = false


func _on_surface_hit(rock: Dictionary) -> void:
	if _white_hole != null and _rng.randf() < white_hole_chance:
		_schedule_white_hole_eject()
	# Lantern slot always returns to the normal cycle.
	_despawn(rock)


func _schedule_white_hole_eject() -> void:
	## Separate from lantern rocks so Hollow's Lantern keeps firing.
	_wh_ejects.append({
		"node": null,
		"wait": white_hole_delay,
		"t": 0.0,
		"dur": _rng.randf_range(white_hole_life_min, white_hole_life_max),
		"dir": _rand_unit(),
		"travel": _rng.randf_range(white_hole_travel_min, white_hole_travel_max),
		"origin": Vector3.ZERO,
		"spin": _rng.randf_range(1.0, 4.0),
		"spawned": false,
	})


func _spawn_white_hole_eject(eject: Dictionary) -> void:
	if _white_hole == null:
		return
	var holder := _white_hole.get_parent() as Node3D
	if holder == null:
		holder = _white_hole
	var mi := _make_rock_mesh("WH_Meteor_%d" % _wh_ejects.size(), true)
	holder.add_child(mi)
	var origin := _white_hole.global_position
	mi.global_position = origin
	mi.visible = true
	eject["node"] = mi
	eject["origin"] = origin
	eject["spawned"] = true
	eject["t"] = 0.0
	eject["emis0"] = 6.5


func _free_white_hole_eject(eject: Dictionary) -> void:
	var n: Node = eject.get("node") as Node
	if n != null and is_instance_valid(n):
		n.queue_free()
	eject["node"] = null
	eject["spawned"] = false


func _process(delta: float) -> void:
	if _moon == null or _planet == null:
		return
	if WallpaperBus.blocks_motion() or WallpaperBus.mode != WallpaperBus.MODE_SOLAR:
		return
	var dt := delta * WallpaperBus.motion_scale()
	_process_lantern(dt)
	_process_white_hole(dt)


func _process_lantern(dt: float) -> void:
	var hit_r := planet_hit_radius + rock_radius * 0.5
	for rock in _rocks:
		if not rock["active"]:
			rock["wait"] = float(rock["wait"]) - dt
			if float(rock["wait"]) > 0.0:
				continue
			_arm(rock)
			continue

		var n: Node3D = rock["node"]
		rock["t"] = float(rock["t"]) + dt / float(rock["dur"])
		var t: float = clampf(float(rock["t"]), 0.0, 1.0)
		if rock["mode"] == "wrap":
			n.position = _wrap_pos(rock, t)
		else:
			var s := t * t * (3.0 - 2.0 * t)
			n.position = _bezier(rock["p0"], rock["p1"], rock["p2"], rock["p3"], s)
		var rock_mi := _rock_mi(n)
		if rock_mi:
			var axis: Vector3 = rock["spin_axis"] if rock.has("spin_axis") else Vector3.UP
			rock_mi.rotate_object_local(axis, dt * float(rock["spin"]))
		rock["prev_pos"] = n.position
		var len_now := n.position.length()
		var prev: float = float(rock["prev_len"])
		var past_launch := t > 0.08
		if past_launch and (len_now <= hit_r or (prev > hit_r and len_now <= hit_r)):
			_on_surface_hit(rock)
			continue
		if t >= 1.0:
			_on_surface_hit(rock)
			continue
		rock["prev_len"] = len_now


func _process_white_hole(dt: float) -> void:
	var i := 0
	while i < _wh_ejects.size():
		var eject: Dictionary = _wh_ejects[i]
		if not eject["spawned"]:
			eject["wait"] = float(eject["wait"]) - dt
			if float(eject["wait"]) > 0.0:
				i += 1
				continue
			_spawn_white_hole_eject(eject)
			if not eject["spawned"]:
				_wh_ejects.remove_at(i)
				continue
			i += 1
			continue

		var n: Node3D = eject["node"]
		if n == null or not is_instance_valid(n):
			_wh_ejects.remove_at(i)
			continue
		eject["t"] = float(eject["t"]) + dt
		var dur := maxf(float(eject["dur"]), 0.001)
		var fade_len := minf(white_hole_fade_len, dur * 0.5)
		var u := clampf(float(eject["t"]) / dur, 0.0, 1.0)
		# Cubic ease-out: fast leave, settle to a stop near the White Hole.
		var ease := 1.0 - pow(1.0 - u, 3.0)
		n.global_position = (eject["origin"] as Vector3) + (eject["dir"] as Vector3) * float(eject["travel"]) * ease
		var rock_mi := _rock_mi(n)
		if rock_mi:
			rock_mi.rotate_y(dt * float(eject["spin"]) * (1.0 - u))
		# Fade out at the end (BH surface hits still pop away instantly).
		var fade_t := (float(eject["t"]) - (dur - fade_len)) / maxf(fade_len, 0.001)
		var visible := 1.0
		if fade_t > 0.0:
			var ft := clampf(fade_t, 0.0, 1.0)
			# Smooth ease-in on the fade so it softens rather than snapping.
			visible = 1.0 - (ft * ft * (3.0 - 2.0 * ft))
		if rock_mi and rock_mi.material_override is ShaderMaterial:
			(rock_mi.material_override as ShaderMaterial).set_shader_parameter("fade", visible)
		elif rock_mi and rock_mi.material_override is StandardMaterial3D:
			var mat := rock_mi.material_override as StandardMaterial3D
			mat.albedo_color.a = visible
			mat.emission_energy_multiplier = float(eject.get("emis0", 40.0)) * visible
		if float(eject["t"]) >= dur:
			_free_white_hole_eject(eject)
			_wh_ejects.remove_at(i)
			continue
		i += 1
