extends Node3D

## Map-view DistantProxy glTFs from Unity (not Kaydara proxies/*.fbx).
## Attlerock is inside TimberHearth_DistantProxy (Moon_Pivot → Proxy_THM).
## Hollow's Lantern is inside BrittleHollow_DistantProxy (VolcanicMoon_Pivot).

const AshTwinSandAimScript := preload("res://scripts/ash_twin_sand_aim.gd")
const TwinsSandTransferScript := preload("res://scripts/twins_sand_transfer.gd")
const VolcanicMeteorsScript := preload("res://scripts/volcanic_meteors.gd")
const GiantsDeepLightningScript := preload("res://scripts/giants_deep_lightning.gd")
const DayNightShadeScript := preload("res://scripts/day_night_shade.gd")
const SupernovaFxScript := preload("res://scripts/supernova_fx.gd")
const RevealWaveScript := preload("res://scripts/reveal_wave.gd")

const GLTF := {
	"sun": "res://assets/gltf/SunProxy.glb",
	"starfield_detail": "res://assets/gltf/StarfieldDetail.glb",
	"timber_hearth": "res://assets/gltf/TimberHearth_DistantProxy.glb",
	"ash_twin": "res://assets/gltf/AshTwin_DistantProxy.glb",
	"ember_twin": "res://assets/gltf/EmberTwin_DistantProxy.glb",
	"brittle_hollow": "res://assets/gltf/BrittleHollow_DistantProxy.glb",
	"brittle_hollow_orbit": "res://assets/gltf/BrittleHollow_Orbit.glb",
	"giants_deep_orbit": "res://assets/gltf/GiantsDeep_Orbit.glb",
	"giants_deep": "res://assets/gltf/GiantsDeep_DistantProxy.glb",
	"dark_bramble": "res://assets/gltf/DarkBramble_DistantProxy.glb",
	"interloper": "res://assets/gltf/Comet_DistantProxy.glb",
	"quantum_moon": "res://assets/gltf/QuantumMoon_DistantProxy.glb",
}

const STARFIELD_V2 := "res://assets/starfield/StarfieldV2.obj"
const STAR_SHADER := "res://shaders/starfield_billboard.gdshader"
const PROXY_SS := "res://assets/proxies/Proxy_SS.fbx"

## Bigger map bodies; orbit radii/periods unchanged. Not applied to sun, starfield,
## Interloper, Giant's Deep, or Dark Bramble.
const BODY_VISUAL_SCALE := 1.75
## Twins sit farther apart so the larger meshes don't crowd.
const TWIN_ORBIT_SCALE := 2.0
## Satellite moons: a little past the old 0.78 pull (Attlerock 702, Lantern 780),
## and drawn larger. Orbit view keeps the wide mesh distance.
const ATTLEROCK_SAT_RADIUS := 1180.0
const LANTERN_SAT_RADIUS := 1320.0
const SATELLITE_MOON_SCALE := 2.15
## Lantern keeps the planet's enlargement only — no second moon boost.
const LANTERN_SAT_SCALE := 0.88
const METEOR_MOON_RADIUS := 95.0
## Satellite cannon only. Orbit view keeps the mesh distance.
const OPC_ORBIT_RADIUS := 1200.0
const OPC_SAT_RADIUS := 1360.0
const OPC_SAT_SCALE := 1.38

var _data: OrbitsData
var _host_nodes: Dictionary = {}
var _line_for: Dictionary = {}
var _reveal: Node
var _bh_body: Node3D
var _bh_close: Node3D
var _bh_moon: Node3D
var _meteors: VolcanicMeteors
var _gd_body: Node3D
var _gd_close: Node3D
var _focus_nodes: Dictionary = {}
var _cull_extra: Array[Node3D] = []
var _cull_focus: String = ""


func _ready() -> void:
	_data = OrbitsData.load_from_res()
	_build_starfield()
	_build_sun()
	_build_orbits()
	WallpaperBus.mode_changed.connect(_on_mode)
	_on_mode(WallpaperBus.mode)


func _on_mode(mode: String) -> void:
	visible = mode == WallpaperBus.MODE_SOLAR
	process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED


func _build_starfield() -> void:
	# Map-view still sky. Each card faces the camera with its own roll so the glints don't repeat.
	var sf := Node3D.new()
	sf.name = "Starfield"
	var mi: MeshInstance3D = null
	var geo: Resource = load(STARFIELD_V2)
	var source: Mesh = null
	if geo is Mesh:
		source = geo as Mesh
	elif geo is PackedScene:
		var inst: Node = (geo as PackedScene).instantiate()
		var found := MeshLoader.find_mesh_instance(inst)
		if found:
			source = found.mesh
		inst.queue_free()
	if source == null:
		var detail := MeshLoader.instantiate_gltf(GLTF["starfield_detail"], 80.0)
		detail.name = "StarfieldDetailFallback"
		sf.add_child(detail)
	else:
		mi = MeshInstance3D.new()
		mi.name = "StarfieldV2"
		mi.mesh = _varied_star_mesh(source)
		var shader := load(STAR_SHADER) as Shader
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mi.material_override = mat
		# Mesh is ~32 units across; scale so it surrounds the isometric camera (~50k).
		mi.scale = Vector3.ONE * 4500.0
		sf.add_child(mi)
	add_child(sf)


func _build_sun() -> void:
	var sun_root := Node3D.new()
	sun_root.name = "Sun"
	var body := MeshLoader.make_sun_body(1850.0)
	body.name = "Body"
	sun_root.add_child(body)
	var light := OmniLight3D.new()
	light.name = "SunLight"
	light.light_color = Color(1.0, 0.55, 0.18)
	light.light_energy = 13.0
	light.omni_range = 36000.0
	light.omni_attenuation = 0.55
	sun_root.add_child(light)
	# Soft fill only for anything still using lit materials (day/night bodies are unshaded).
	var fill := DirectionalLight3D.new()
	fill.name = "SunFill"
	fill.light_color = Color(1.0, 0.65, 0.28)
	fill.light_energy = 0.2
	fill.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	sun_root.add_child(fill)
	add_child(sun_root)
	# Supernova FX needs the HUD fade layer; resolve next frame once siblings exist.
	call_deferred("_attach_supernova", sun_root)


func _build_orbits() -> void:
	var hgt := _make_circular(
		"OrbitRoot_HGT",
		_data.semi_major("hourglass_twins_barycenter"),
		_data.period("hourglass_twins_barycenter"),
		0.0
	)
	add_child(hgt)

	var twin_r := _data.semi_major("ash_twin") * TWIN_ORBIT_SCALE
	var ash := _make_circular(
		"AshTwin",
		twin_r,
		_data.period("ash_twin", "period_seconds_game"),
		float(_data.body("ash_twin").get("orbit", {}).get("phase_offset_deg", 0.0))
	)
	var ash_body := MeshLoader.instantiate_gltf(GLTF["ash_twin"])
	ash_body.name = "Body"
	ash.add_child(ash_body)
	_enlarge_on_orbit(ash_body, BODY_VISUAL_SCALE)

	var ember := _make_circular(
		"EmberTwin",
		twin_r,
		_data.period("ember_twin", "period_seconds_game"),
		float(_data.body("ember_twin").get("orbit", {}).get("phase_offset_deg", 180.0))
	)
	var ember_body := MeshLoader.instantiate_gltf(GLTF["ember_twin"])
	ember_body.name = "Body"
	ember.add_child(ember_body)
	_enlarge_on_orbit(ember_body, BODY_VISUAL_SCALE)

	hgt.add_child(ash)
	hgt.add_child(ember)
	# QM on "twins" orbits the barycenter (imaginary encapsulating body), not one twin.
	_host_nodes["ember_twin"] = hgt
	_host_nodes["ash_twin"] = hgt
	_host_nodes["hourglass_twins"] = hgt

	var sand_aim = AshTwinSandAimScript.new()
	sand_aim.name = "AshTwinSandAim"
	sand_aim.setup(ash_body, ember)
	ash.add_child(sand_aim)

	var sand_xfer = TwinsSandTransferScript.new()
	sand_xfer.name = "TwinsSandTransfer"
	sand_xfer.setup(ash, ember, ember_body)
	hgt.add_child(sand_xfer)

	var th := _make_circular(
		"OrbitRoot_TH",
		_data.semi_major("timber_hearth"),
		_data.period("timber_hearth"),
		30.0
	)
	th.spin_period_seconds = float(_data.body("timber_hearth").get("rotation_period_seconds_game", 0.0))
	var th_body := MeshLoader.instantiate_gltf(GLTF["timber_hearth"])
	th_body.name = "Body"
	th.add_child(th_body)
	_attach_moon_spin(th_body, "Moon_Pivot", _data.period("attlerock", "period_seconds_game"))
	_enlarge_on_orbit(th_body, BODY_VISUAL_SCALE)
	add_child(th)
	_host_nodes["timber_hearth"] = th

	var bh := _make_circular(
		"OrbitRoot_BH",
		_data.semi_major("brittle_hollow"),
		_data.period("brittle_hollow"),
		80.0
	)
	bh.spin_period_seconds = float(_data.body("brittle_hollow").get("rotation_period_seconds_game", 0.0))
	var bh_body := MeshLoader.instantiate_gltf(GLTF["brittle_hollow"])
	bh_body.name = "Body"
	MeshLoader.strip_map_interiors(bh_body)
	bh.add_child(bh_body)
	_attach_moon_spin(bh_body, "VolcanicMoon_Pivot", _data.period("hollows_lantern", "period_seconds_game"))
	_enlarge_on_orbit(bh_body, BODY_VISUAL_SCALE)
	_bh_body = bh_body
	var vm_body := MeshLoader.repair_volcanic_moon(bh_body)
	if vm_body:
		var lava_light := OmniLight3D.new()
		lava_light.name = "HollowsLanternLight"
		lava_light.light_color = Color(1.0, 0.35, 0.05)
		lava_light.light_energy = 5.0
		# Under 0.01 DistantProxy → scale range so world reach ≈ 1200m.
		lava_light.omni_range = 120000.0
		vm_body.add_child(lava_light)
		var meteors := VolcanicMeteorsScript.new()
		meteors.name = "VolcanicMeteors"
		meteors.moon_radius = METEOR_MOON_RADIUS * BODY_VISUAL_SCALE * LANTERN_SAT_SCALE
		meteors.planet_hit_radius *= BODY_VISUAL_SCALE
		bh.add_child(meteors)
		meteors.setup(vm_body, bh)
		_bh_moon = vm_body
		_meteors = meteors
		# White Hole is built later; wire exit portal then.
		set_meta("_volcanic_meteors", meteors)
	add_child(bh)
	_host_nodes["brittle_hollow"] = bh

	var gd := _make_circular(
		"OrbitRoot_GD",
		_data.semi_major("giants_deep"),
		_data.period("giants_deep"),
		140.0
	)
	var gd_body := MeshLoader.instantiate_gltf(GLTF["giants_deep"])
	gd_body.name = "Body"
	gd.add_child(gd_body)
	_gd_body = gd_body
	MeshLoader.repair_giants_deep(gd_body)
	# OPC — Unity has no period; wallpaper crawl (~3.5× slower than prior 51s). Opposite of prior spin.
	var opc_period := float(_data.flavor.get("orbital_probe_cannon", {}).get("period_seconds_game", 51.09)) * 3.5
	_attach_moon_spin(gd_body, "OrbitalProbeCannon_Pivot", opc_period, -1.0)
	var bolts = GiantsDeepLightningScript.new()
	bolts.name = "GiantsDeepLightning"
	gd.add_child(bolts)
	add_child(gd)
	_host_nodes["giants_deep"] = gd

	var db := _make_circular(
		"OrbitRoot_DB",
		_data.semi_major("dark_bramble"),
		_data.period("dark_bramble"),
		200.0
	)
	# Unity angular speed is 0; slow wallpaper spin so it doesn't read as a flat billboard.
	db.spin_period_seconds = 720.0
	var db_body := MeshLoader.instantiate_gltf(GLTF["dark_bramble"])
	db_body.name = "Body"
	db.add_child(db_body)
	MeshLoader.repair_dark_bramble(db_body)
	add_child(db)
	_host_nodes["dark_bramble"] = db

	var interloper := BodyOrbit.new()
	interloper.name = "Interloper"
	interloper.orbit_type = BodyOrbit.OrbitType.ELLIPTICAL
	# Raise perihelion above solid sun (~3000): a=13550, e≈0.779 (Unity peri was 2400).
	interloper.radius = 13550.0
	interloper.period_seconds = _data.period("interloper")
	interloper.eccentricity = 0.779
	interloper.focal_distance = 10550.0
	interloper.face_primary = false
	interloper.face_comet_tail = true
	var co := MeshLoader.instantiate_gltf(GLTF["interloper"])
	co.name = "Body"
	interloper.add_child(co)
	add_child(interloper)

	# Sun Station — bottoms (−Y) toward sun; platforms (±X) along world up (straddle ecliptic).
	var ss_sma := 1980.0
	var ss_period := 34.57 * (ss_sma / 2296.0)
	var ss := _make_circular("SunStation", ss_sma, ss_period, 15.0)
	ss.face_nadir = true
	var ss_body := _instantiate_proxy_fbx(PROXY_SS, Color(0.95, 0.85, 0.55), true)
	ss_body.name = "Body"
	ss.add_child(ss_body)
	_enlarge_on_orbit(ss_body, BODY_VISUAL_SCALE)
	add_child(ss)

	# White Hole — Unity singularity (~39m). Keep smaller than QM (~192m after scale);
	# prior bloom shell read larger than the moon.
	var wh := Node3D.new()
	wh.name = "WhiteHole"
	wh.position = Vector3(-23000.0, 0.0, 0.0)
	var wh_core := MeshLoader.make_emissive_sphere(39.225, Color(1.0, 1.0, 1.0))
	wh_core.name = "WhiteHoleSingularity"
	var wh_mat := wh_core.material_override as StandardMaterial3D
	wh_mat.albedo_color = Color(1.0, 1.0, 1.0)
	wh_mat.emission = Color(1.0, 1.0, 1.0)
	wh_mat.emission_energy_multiplier = 12.0
	wh.add_child(wh_core)
	var wh_glow := MeshLoader.make_emissive_sphere(88.0, Color(1.0, 1.0, 1.0))
	wh_glow.name = "WhiteHoleBloom"
	var wh_glow_mat := wh_glow.material_override as StandardMaterial3D
	wh_glow_mat.albedo_color = Color(1.0, 1.0, 1.0)
	wh_glow_mat.emission = Color(1.0, 1.0, 1.0)
	wh_glow_mat.emission_energy_multiplier = 8.0
	wh.add_child(wh_glow)
	var wh_light := OmniLight3D.new()
	wh_light.name = "WhiteHoleLight"
	wh_light.light_color = Color(1.0, 1.0, 1.0)
	wh_light.light_energy = 8.0
	wh_light.omni_range = 3500.0
	wh.add_child(wh_light)
	add_child(wh)
	if has_meta("_volcanic_meteors"):
		var meteors = get_meta("_volcanic_meteors")
		if meteors and meteors.has_method("set_white_hole"):
			meteors.set_white_hole(wh)
		remove_meta("_volcanic_meteors")

	# Follow the moon meshes (offset children), not the pivots — pivots sit at the planet origin.
	var attlerock := MeshLoader.find_node_by_name(th_body, "Proxy_THM")
	if attlerock == null:
		attlerock = MeshLoader.find_node_by_name(th_body, "Moon_Pivot")
	var hollows := MeshLoader.find_node_by_name(bh_body, "VolcanicMoon_Body")
	if hollows == null:
		hollows = MeshLoader.find_node_by_name(bh_body, "VolcanicMoon_Pivot")
	# Satellite view only. The Brittle Hollow close mesh keeps the wide lantern distance.
	_set_moon_world_orbit(th_body, attlerock, ATTLEROCK_SAT_RADIUS)
	_set_moon_world_orbit(bh_body, hollows, LANTERN_SAT_RADIUS)
	if attlerock:
		attlerock.scale *= SATELLITE_MOON_SCALE
	if hollows:
		hollows.scale *= LANTERN_SAT_SCALE
	var attlerock_r := ATTLEROCK_SAT_RADIUS
	var hollows_r := LANTERN_SAT_RADIUS
	# Gap must track the sideways cannon's visual center (base alone sits ahead of the barrel).
	_enlarge_satellite_opc(gd_body)
	var opc := _make_opc_gap_anchor(gd_body)
	_build_orbit_lines(
		hgt, th, bh, gd, db, ss, interloper, attlerock, hollows, opc, attlerock_r, hollows_r
	)

	# Day/night (sun at origin). Skip Sun Station / Interloper / White Hole.
	DayNightShadeScript.attach(ash, ash_body)
	DayNightShadeScript.attach(ember, ember_body)
	DayNightShadeScript.attach(th, th_body, null, 0.0, PackedStringArray(["Moon_Pivot"]))
	if attlerock:
		DayNightShadeScript.attach(th, attlerock, th, 520.0 * BODY_VISUAL_SCALE)
	DayNightShadeScript.attach(bh, bh_body, null, 0.0, PackedStringArray(["VolcanicMoon_Pivot"]))
	if hollows:
		DayNightShadeScript.attach(bh, hollows, bh, 340.0 * BODY_VISUAL_SCALE)
	DayNightShadeScript.attach(gd, gd_body, null, 0.0, PackedStringArray(["OrbitalProbeCannon_Pivot"]))
	var opc_body := MeshLoader.find_node_by_name(gd_body, "OrbitalProbeCannon_Pivot")
	_shade_opc(gd, opc_body, gd)
	DayNightShadeScript.attach(db, db_body)

	var qm := QuantumMoon.new()
	qm.name = "QuantumMoon"
	th.add_child(qm)
	var qm_mesh := MeshLoader.make_quantum_moon_body(110.0 * BODY_VISUAL_SCALE)
	qm.setup(_data.qm_hosts, _host_nodes, qm_mesh)
	var qm_dn: DayNightShade = DayNightShadeScript.attach(qm, qm_mesh)
	qm.set_day_night(qm_dn, _host_nodes)
	_focus_nodes = {
		"hourglass_twins": hgt,
		"timber_hearth": th,
		"brittle_hollow": bh,
		"giants_deep": gd,
		"dark_bramble": db,
	}
	_cull_extra = [ss, wh]
	_setup_reveal_wave(ss, hgt, th, bh, interloper, gd, db, wh)


func _build_orbit_lines(
	hgt: BodyOrbit, th: BodyOrbit, bh: BodyOrbit, gd: BodyOrbit, db: BodyOrbit,
	ss: BodyOrbit, interloper: BodyOrbit, attlerock: Node3D, hollows: Node3D,
	opc: Node3D = null,
	attlerock_r: float = 900.0,
	hollows_r: float = 1000.0
) -> void:
	var lines := Node3D.new()
	lines.name = "OrbitLines"
	var white := Color(1, 1, 1, 1.0)
	# gap = half arc length in world units; gap_trail = extra trailing-only clearance.
	var specs: Array = [
		# Twins sit ±500m from barycenter and are large — clear the trailing twin.
		{"r": _data.semi_major("hourglass_twins_barycenter"), "gap": 640.0, "gap_trail": 520.0, "follow": hgt, "w": 36.0},
		{"r": _data.semi_major("timber_hearth"), "gap": 380.0, "follow": th, "w": 36.0},
		{"r": _data.semi_major("brittle_hollow"), "gap": 320.0, "follow": bh, "w": 36.0},
		{"r": _data.semi_major("giants_deep"), "gap": 700.0, "follow": gd, "w": 40.0},
		{"r": _data.semi_major("dark_bramble"), "gap": 420.0, "follow": db, "w": 36.0},
		{"r": 1980.0, "gap": 160.0, "follow": ss, "w": 28.0},
	]
	for spec in specs:
		var line := OrbitLine.new()
		line.name = "OrbitLine_%d" % int(spec["r"])
		line.setup_circular(
			float(spec["r"]),
			white,
			float(spec["w"]),
			float(spec["gap"]),
			spec["follow"] as Node3D,
			float(spec.get("gap_trail", 0.0))
		)
		lines.add_child(line)
		_line_for[spec["follow"]] = line
	var co_line := OrbitLine.new()
	co_line.name = "OrbitLine_Interloper"
	var e := interloper.eccentricity
	if e <= 0.0 and interloper.radius > 0.0:
		e = clampf(interloper.focal_distance / interloper.radius, 0.0, 0.99)
	co_line.setup_ellipse(interloper.radius, e, white, 36.0, interloper, 280.0)
	lines.add_child(co_line)
	_line_for[interloper] = co_line
	var th_moon := OrbitLine.new()
	th_moon.name = "OrbitLine_Attlerock"
	th_moon.setup_circular(attlerock_r, white, 24.0, 420.0, attlerock)
	th.add_child(th_moon)
	var bh_moon := OrbitLine.new()
	bh_moon.name = "OrbitLine_HollowsLantern"
	bh_moon.setup_circular(hollows_r, white, 24.0, 280.0, hollows)
	bh.add_child(bh_moon)
	if opc:
		var opc_line := OrbitLine.new()
		opc_line.name = "OrbitLine_OPC"
		# Satellite cannon sits a little further out so the larger mesh clears the clouds.
		opc_line.setup_circular(OPC_SAT_RADIUS, white, 22.0, 560.0, opc)
		gd.add_child(opc_line)
	add_child(lines)


func _make_opc_gap_anchor(gd_body: Node3D) -> Node3D:
	## Average Body / Barrel / Muzzle so the orbit break sits on the sideways cannon, not the base.
	var pivot := MeshLoader.find_node_by_name(gd_body, "OrbitalProbeCannon_Pivot")
	if pivot == null:
		return MeshLoader.find_node_by_name(gd_body, "OrbitalProbeCannon_Body")
	var parts: Array[Node3D] = []
	for nm in ["OrbitalProbeCannon_Body", "CannonBarrel_Body", "CannonMuzzle_Body"]:
		var p := MeshLoader.find_node_by_name(pivot, nm)
		if p:
			parts.append(p)
	if parts.is_empty():
		return pivot
	var sum := Vector3.ZERO
	for p in parts:
		sum += p.position
	var anchor := Node3D.new()
	anchor.name = "OPC_OrbitGapAnchor"
	anchor.position = sum / float(parts.size())
	pivot.add_child(anchor)
	return anchor


func _instantiate_proxy_fbx(path: String, fallback_color: Color, recenter: bool = false) -> Node3D:
	# Kaydara Proxy_*.fbx are already ~game metres — do NOT apply DistantProxy 0.01.
	var res: Resource = load(path)
	if res is PackedScene:
		var root := Node3D.new()
		var inst: Node = (res as PackedScene).instantiate()
		root.add_child(inst)
		root.scale = Vector3.ONE
		MeshLoader._fix_materials_recursive(inst)
		if recenter:
			_recenter_proxy_meshes(root)
		return root
	var marker := MeshLoader.make_emissive_sphere(80.0, fallback_color)
	var wrap := Node3D.new()
	wrap.add_child(marker)
	push_warning("solar_system: missing %s — using marker" % path)
	return wrap


func _recenter_proxy_meshes(root: Node3D) -> void:
	## Proxy_SS.fbx bakes ~2.2km into the mesh (AABB far from origin) → reads as a sun halo.
	var merged: Variant = null
	for mi in MeshLoader._collect_mesh_instances(root):
		var xform := Transform3D.IDENTITY
		var p: Node = mi
		while p and p != root:
			if p is Node3D:
				xform = (p as Node3D).transform * xform
			p = p.get_parent()
		var a: AABB = xform * mi.mesh.get_aabb()
		merged = a if merged == null else (merged as AABB).merge(a)
	if merged == null:
		return
	var center: Vector3 = (merged as AABB).get_center()
	if center.length_squared() < 1.0:
		return
	for c in root.get_children():
		if c is Node3D:
			(c as Node3D).position -= center


var _cached_lines: Array[OrbitLine] = []
var _lines_cached: bool = false


func set_brittle_hollow_close(enabled: bool) -> void:
	## Heavier crust only while the camera is on Brittle Hollow. Satellite keeps the light mesh.
	if not enabled:
		if _bh_body:
			_bh_body.visible = true
		if _meteors and _bh_moon:
			_meteors.set_launch_moon(_bh_moon, METEOR_MOON_RADIUS * BODY_VISUAL_SCALE * LANTERN_SAT_SCALE, false)
		if _bh_close != null and is_instance_valid(_bh_close):
			_bh_close.queue_free()
		_bh_close = null
		return
	if _bh_close != null and is_instance_valid(_bh_close):
		return
	if _bh_body == null:
		return
	var close := MeshLoader.instantiate_gltf(GLTF["brittle_hollow_orbit"])
	close.name = "BodyClose"
	if MeshLoader.find_node_by_name(close, "VolcanicMoon_Body") == null:
		close.queue_free()
		push_warning("solar_system: Brittle Hollow orbit mesh unavailable")
		return
	MeshLoader.strip_map_interiors(close)
	var crust := MeshLoader.prepare_brittle_hollow_orbit(close)
	var bh := _bh_body.get_parent()
	if bh == null:
		close.queue_free()
		return
	bh.add_child(close)
	_enlarge_on_orbit(close, BODY_VISUAL_SCALE)
	var lantern := MeshLoader.repair_volcanic_moon(close, true)
	var hollows := lantern if lantern else MeshLoader.find_node_by_name(close, "VolcanicMoon_Body")
	if hollows == null:
		hollows = MeshLoader.find_node_by_name(close, "VolcanicMoon_Pivot")
	if hollows and hollows.get_node_or_null("HollowsLanternLight") == null:
		var lava_light := OmniLight3D.new()
		lava_light.name = "HollowsLanternLight"
		lava_light.light_color = Color(1.0, 0.42, 0.08)
		lava_light.light_energy = 8.0
		lava_light.omni_range = 120000.0
		hollows.add_child(lava_light)
	var period := _data.period("hollows_lantern", "period_seconds_game")
	_attach_moon_spin(close, "VolcanicMoon_Pivot", period)
	var low_spin := _bh_body.get_node_or_null("VolcanicMoon_Pivot_Spin") as MoonPivotSpin
	var close_spin := close.get_node_or_null("VolcanicMoon_Pivot_Spin") as MoonPivotSpin
	if low_spin != null and close_spin != null:
		close_spin._angle = low_spin._angle
		if close_spin._pivot:
			close_spin._pivot.rotation.y = low_spin._angle
	var crust_shade := DayNightShadeScript.attach(close, close, null, 0.0, PackedStringArray(["VolcanicMoon_Pivot"]))
	MeshLoader.lock_brittle_crust(close, crust)
	if crust and crust_shade:
		crust_shade.track(crust)
	if hollows:
		_set_moon_world_orbit(close, hollows, LANTERN_SAT_RADIUS)
		_match_moon_size(hollows, _bh_moon)
		_snap_moon_center(hollows, _bh_moon)
		var lantern_shade := DayNightShadeScript.attach(close, hollows, bh, 340.0 * BODY_VISUAL_SCALE)
		if lantern_shade:
			lantern_shade.set_eclipse_floor(0.26)
		if _meteors:
			_meteors.set_launch_moon(hollows, METEOR_MOON_RADIUS * BODY_VISUAL_SCALE * LANTERN_SAT_SCALE, true)
	_bh_body.visible = false
	_bh_close = close


func _snap_moon_center(dst: Node3D, src: Node3D) -> void:
	## The orbit mesh's pivot is not the visual center. Sit that center on the satellite moon.
	if dst == null or src == null:
		return
	var want: Variant = _world_mesh_center(src)
	var have: Variant = _world_mesh_center(dst)
	if want == null or have == null:
		return
	dst.global_position += (want as Vector3) - (have as Vector3)


func _world_mesh_center(node: Node3D) -> Variant:
	var merged: Variant = null
	for mi in MeshLoader._collect_mesh_instances(node):
		if mi.mesh == null or _mesh_under(mi, "LavaSphere"):
			continue
		var box: AABB = mi.global_transform * mi.mesh.get_aabb()
		merged = box if merged == null else (merged as AABB).merge(box)
	if merged == null:
		return null
	return (merged as AABB).get_center()


func _match_moon_size(dst: Node3D, src: Node3D) -> void:
	## Keep the satellite moon's size when the orbit mesh replaces it.
	if dst == null or src == null:
		return
	var want := _world_mesh_radius(src)
	var have := _world_mesh_radius(dst)
	if want < 1.0 or have < 1.0:
		return
	dst.scale *= want / have


func _mesh_under(node: Node, named: String) -> bool:
	var n := node
	while n:
		if String(n.name) == named:
			return true
		n = n.get_parent()
	return false


func _world_mesh_radius(node: Node3D) -> float:
	var merged: Variant = null
	for mi in MeshLoader._collect_mesh_instances(node):
		if mi.mesh == null:
			continue
		if _mesh_under(mi, "LavaSphere"):
			continue
		var box: AABB = mi.global_transform * mi.mesh.get_aabb()
		merged = box if merged == null else (merged as AABB).merge(box)
	if merged == null:
		return 0.0
	return (merged as AABB).size.length() * 0.5


func _enlarge_satellite_opc(gd_body: Node3D) -> void:
	var pivot := MeshLoader.find_node_by_name(gd_body, "OrbitalProbeCannon_Pivot")
	if pivot == null:
		return
	var ratio := OPC_SAT_RADIUS / OPC_ORBIT_RADIUS
	for nm in ["OrbitalProbeCannon_Body", "CannonBarrel_Body", "CannonMuzzle_Body"]:
		var part := MeshLoader.find_node_by_name(pivot, nm)
		if part == null:
			continue
		var flat := Vector3(part.position.x, 0.0, part.position.z)
		if flat.length() < 1.0:
			continue
		part.position = Vector3(part.position.x * ratio, part.position.y, part.position.z * ratio)
	for mi in MeshLoader._collect_mesh_instances(pivot):
		mi.scale *= OPC_SAT_SCALE


func _shade_opc(parent: Node, pivot: Node3D, planet: Node3D) -> void:
	## Each cannon segment samples the planet's shadow on its own, so a long barrel
	## can be half in the umbra.
	if pivot == null or planet == null:
		return
	MeshLoader.tone_opc(pivot)
	var shade := DayNightShadeScript.attach(parent, pivot, planet, 950.0)
	shade.per_part_umbra = true
	shade.set_light_levels(0.18, 0.78)


func set_giants_deep_close(enabled: bool) -> void:
	var bolts := find_child("GiantsDeepLightning", true, false)
	if not enabled:
		if bolts and bolts.has_method("set_orbit_detail"):
			bolts.set_orbit_detail(false)
		if _gd_body:
			_gd_body.visible = true
		if _gd_close != null and is_instance_valid(_gd_close):
			_gd_close.queue_free()
		_gd_close = null
		return
	if _gd_close != null and is_instance_valid(_gd_close):
		return
	if _gd_body == null:
		return
	var close := MeshLoader.instantiate_gltf(GLTF["giants_deep"])
	close.name = "BodyClose"
	if MeshLoader.find_node_by_name(close, "CloudsTopLayer_GD__1_") == null and MeshLoader.find_node_by_name(close, "Proxy_GD") == null:
		close.queue_free()
		push_warning("solar_system: Giant's Deep orbit mesh unavailable")
		return
	var gd := _gd_body.get_parent()
	if gd == null:
		close.queue_free()
		return
	gd.add_child(close)
	MeshLoader.refine_gd_atmosphere(close)
	MeshLoader.repair_giants_deep(close, true)
	var opc_period := float(_data.flavor.get("orbital_probe_cannon", {}).get("period_seconds_game", 51.09)) * 3.5
	_attach_moon_spin(close, "OrbitalProbeCannon_Pivot", opc_period, -1.0)
	var low_spin := _gd_body.get_node_or_null("OrbitalProbeCannon_Pivot_Spin") as MoonPivotSpin
	var close_spin := close.get_node_or_null("OrbitalProbeCannon_Pivot_Spin") as MoonPivotSpin
	if low_spin != null and close_spin != null:
		close_spin._angle = low_spin._angle
		if close_spin._pivot:
			close_spin._pivot.rotation.y = low_spin._angle
	DayNightShadeScript.attach(close, close, null, 0.0, PackedStringArray(["OrbitalProbeCannon_Pivot"]))
	var opc_body := MeshLoader.find_node_by_name(close, "OrbitalProbeCannon_Pivot")
	_shade_opc(close, opc_body, gd)
	var storm_mat := MeshLoader.apply_gd_storm_cloud(close)
	var shade := close.get_node_or_null("DayNightShade_BodyClose") as DayNightShade
	if shade and storm_mat:
		shade.track(storm_mat)
	if bolts and bolts.has_method("set_orbit_detail"):
		bolts.set_orbit_detail(true)
		if bolts.has_method("set_cloud_material"):
			bolts.set_cloud_material(storm_mat)
	_gd_body.visible = false
	_gd_close = close


func set_brittle_hollow_blend(amount: float) -> void:
	var a := clampf(amount, 0.0, 1.0)
	if a <= 0.001:
		set_brittle_hollow_close(false)
		_fade_body(_bh_body, 1.0)
		return
	if _bh_close == null:
		set_brittle_hollow_close(true)
	if _bh_body:
		_bh_body.visible = a < 0.98
		_fade_body(_bh_body, 1.0 - a)
	if _bh_close:
		_bh_close.visible = true
		_fade_body(_bh_close, a)


func set_giants_deep_blend(amount: float) -> void:
	var a := clampf(amount, 0.0, 1.0)
	if a <= 0.001:
		set_giants_deep_close(false)
		_fade_body(_gd_body, 1.0)
		return
	if _gd_close == null:
		set_giants_deep_close(true)
	if _gd_body:
		_gd_body.visible = a < 0.98
		_fade_body(_gd_body, 1.0 - a)
	if _gd_close:
		_gd_close.visible = true
		_fade_body(_gd_close, a)


func _fade_body(body: Node3D, fade: float) -> void:
	if body == null:
		return
	var host := body.get_parent()
	if host == null:
		return
	for c in host.get_children():
		if c is DayNightShade and (c as DayNightShade).covers(body):
			(c as DayNightShade).set_fade(fade)


func set_orbit_cull(focus_id: String) -> void:
	## Hide every other planet while the camera is on one, so the close mesh can spend the frame.
	if focus_id == _cull_focus:
		return
	_cull_focus = focus_id
	var orbiting := not focus_id.is_empty()
	for id in _focus_nodes.keys():
		var n: Node3D = _focus_nodes[id]
		if n:
			n.visible = (not orbiting) or id == focus_id
	for n in _cull_extra:
		if n:
			n.visible = not orbiting


func set_orbit_lines_fade(amount: float) -> void:
	var f := clampf(amount, 0.0, 1.0)
	if not _lines_cached:
		_collect_orbit_lines(self)
		_lines_cached = true
	for line in _cached_lines:
		if is_instance_valid(line):
			line.set_fade(f)


func set_interloper_visible(shown: bool) -> void:
	var interloper := find_child("Interloper", true, false) as Node3D
	if interloper:
		interloper.visible = shown


func _collect_orbit_lines(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		if c is OrbitLine:
			_cached_lines.append(c as OrbitLine)
		_collect_orbit_lines(c)


func set_orbit_line_visible(body: Node, shown: bool) -> void:
	var line := _line_for.get(body) as Node3D
	if line:
		line.visible = shown
	# Moon and cannon rings are children of the body. They read as that planet's orbit line up close.
	_set_local_orbit_lines(body, shown)


func _set_local_orbit_lines(node: Node, shown: bool) -> void:
	if node == null:
		return
	for c in node.get_children():
		if c is OrbitLine:
			(c as Node3D).visible = shown
		_set_local_orbit_lines(c, shown)


func park_reveal_wave() -> void:
	if _reveal and _reveal.has_method("park"):
		_reveal.park()


func play_reveal_wave() -> void:
	if _reveal and _reveal.has_method("play"):
		_reveal.play()


func cancel_reveal_wave() -> void:
	if _reveal and _reveal.has_method("snap_home"):
		_reveal.snap_home()


func _setup_reveal_wave(
	ss: BodyOrbit,
	hgt: BodyOrbit,
	th: BodyOrbit,
	bh: BodyOrbit,
	interloper: BodyOrbit,
	gd: BodyOrbit,
	db: BodyOrbit,
	wh: Node3D
) -> void:
	wh.set_meta("reveal_home", wh.position)
	var entries: Array[Dictionary] = [
		{"radius": ss.radius, "bodies": [ss], "lines": [_line_for.get(ss)], "points": []},
		{"radius": hgt.radius, "bodies": [hgt], "lines": [_line_for.get(hgt)], "points": []},
		{"radius": th.radius, "bodies": [th], "lines": [_line_for.get(th)], "points": []},
		{"radius": bh.radius, "bodies": [bh], "lines": [_line_for.get(bh)], "points": []},
		{"radius": interloper.radius, "bodies": [interloper], "lines": [_line_for.get(interloper)], "points": []},
		{"radius": gd.radius, "bodies": [gd], "lines": [_line_for.get(gd)], "points": []},
		{"radius": db.radius, "bodies": [db], "lines": [_line_for.get(db)], "points": []},
		{"radius": wh.position.length(), "bodies": [], "lines": [], "points": [wh]},
	]
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["radius"]) < float(b["radius"]))
	var wave := RevealWaveScript.new()
	wave.name = "RevealWave"
	add_child(wave)
	wave.setup(entries)
	_reveal = wave


func _attach_supernova(sun_root: Node3D) -> void:
	var hud := get_parent().get_node_or_null("DebugHud") as CanvasLayer
	if hud == null:
		push_warning("solar_system: DebugHud missing — supernova fade skipped")
	var fx = SupernovaFxScript.new()
	fx.name = "SupernovaFx"
	add_child(fx)
	fx.setup(sun_root, hud)


func _vcomp(v: Vector3, axis: int) -> float:
	if axis == 0:
		return v.x
	if axis == 1:
		return v.y
	return v.z


func _flat_orbit_radius(planet_body: Node3D, moon: Node3D) -> float:
	if planet_body == null or moon == null:
		return 0.0
	var delta := moon.global_position - planet_body.global_position
	delta.y = 0.0
	return delta.length()


func _varied_star_mesh(source: Mesh) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var quads: Array[PackedInt32Array] = []
	var tris: Array[PackedInt32Array] = []
	if indices.size() >= 6:
		var i := 0
		while i + 5 < indices.size():
			var ids := PackedInt32Array()
			var tri := PackedInt32Array()
			for k in 6:
				var id := indices[i + k]
				tri.append(id)
				if not ids.has(id):
					ids.append(id)
			if ids.size() == 4:
				quads.append(ids)
				tris.append(tri)
				i += 6
			else:
				i += 3
	if quads.is_empty():
		var fallback := ArrayMesh.new()
		fallback.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return fallback
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_uv2 := PackedVector2Array()
	var out_c := PackedColorArray()
	var out_i := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x51A25
	for q in quads.size():
		var ids: PackedInt32Array = quads[q]
		var tri: PackedInt32Array = tris[q]
		var center := Vector3.ZERO
		for id in ids:
			center += verts[id]
		center /= 4.0
		var rels: Array[Vector3] = []
		var span := Vector3.ZERO
		for id in ids:
			var rel := verts[id] - center
			rels.append(rel)
			span.x = maxf(span.x, absf(rel.x))
			span.y = maxf(span.y, absf(rel.y))
			span.z = maxf(span.z, absf(rel.z))
		var axis_a := 0
		var axis_b := 1
		if span.z >= span.x or span.z >= span.y:
			if span.x <= span.y and span.x <= span.z:
				axis_a = 1
				axis_b = 2
			elif span.y <= span.x and span.y <= span.z:
				axis_a = 0
				axis_b = 2
		var size_mul := rng.randf_range(0.72, 1.45)
		var roll := rng.randf()
		var bright := rng.randf_range(0.38, 1.0)
		var glint := 0.15 if rng.randf() > 0.42 else rng.randf_range(0.55, 1.0)
		var warm := rng.randf()
		var base := out_v.size()
		var max_x := 0.0
		var max_y := 0.0
		for rel in rels:
			max_x = maxf(max_x, absf(_vcomp(rel, axis_a)) * size_mul)
			max_y = maxf(max_y, absf(_vcomp(rel, axis_b)) * size_mul)
		var local := {}
		for n in ids.size():
			local[ids[n]] = n
			var rel: Vector3 = rels[n]
			var corner := Vector2(_vcomp(rel, axis_a), _vcomp(rel, axis_b)) * size_mul
			out_v.append(center)
			out_n.append(Vector3.UP)
			out_uv.append(Vector2(corner.x / maxf(max_x, 0.00001), corner.y / maxf(max_y, 0.00001)) * 0.5 + Vector2(0.5, 0.5))
			out_uv2.append(corner * 0.38)
			out_c.append(Color(roll, bright, glint, warm))
		for src in tri:
			out_i.append(base + int(local[src]))
	var mesh := ArrayMesh.new()
	var built := []
	built.resize(Mesh.ARRAY_MAX)
	built[Mesh.ARRAY_VERTEX] = out_v
	built[Mesh.ARRAY_NORMAL] = out_n
	built[Mesh.ARRAY_TEX_UV] = out_uv
	built[Mesh.ARRAY_TEX_UV2] = out_uv2
	built[Mesh.ARRAY_COLOR] = out_c
	built[Mesh.ARRAY_INDEX] = out_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built)
	return mesh


func _enlarge_on_orbit(body: Node3D, factor: float) -> void:
	## Grow the mesh; keep the body center on the same heliocentric orbit.
	if body == null or is_equal_approx(factor, 1.0):
		return
	body.scale *= factor


func _set_moon_world_orbit(planet_body: Node3D, moon: Node3D, world_radius: float) -> void:
	## Place the moon at `world_radius` from the planet center (XZ). Scales the
	## first ancestor-under-planet that carries a radial local offset.
	if planet_body == null or moon == null or world_radius <= 0.0:
		return
	var delta := moon.global_position - planet_body.global_position
	delta.y = 0.0
	var cur := delta.length()
	if cur < 1.0:
		return
	var ratio := world_radius / cur
	var n: Node3D = moon
	while n != null and n != planet_body:
		var flat := Vector3(n.position.x, 0.0, n.position.z)
		if flat.length() > 0.01:
			n.position = Vector3(n.position.x * ratio, n.position.y, n.position.z * ratio)
			return
		n = n.get_parent() as Node3D


func _attach_moon_spin(body_root: Node3D, pivot_name: String, period: float, direction: float = 1.0) -> void:
	var pivot := MeshLoader.find_node_by_name(body_root, pivot_name)
	if pivot == null:
		push_warning("solar_system: missing moon pivot '%s'" % pivot_name)
		return
	var spin := MoonPivotSpin.new()
	spin.name = "%s_Spin" % pivot_name
	spin.setup(pivot, period, direction)
	body_root.add_child(spin)


func _make_circular(node_name: String, radius: float, period: float, phase_deg: float) -> BodyOrbit:
	var n := BodyOrbit.new()
	n.name = node_name
	n.orbit_type = BodyOrbit.OrbitType.CIRCULAR
	n.radius = radius
	n.period_seconds = period
	n.phase_offset_deg = phase_deg
	return n
