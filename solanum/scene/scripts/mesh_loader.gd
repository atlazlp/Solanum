class_name MeshLoader
extends RefCounted

## Unity FBX→glTF export often lands in centimetres (100× game metres).
const DISTANT_PROXY_SCALE := 0.01

## Map-view shaders (fog ramps, atmo shells, supernova) become solid white in Godot.
const HIDE_NAME_MATCHES := [
	"FogSphere",
	"Atmosphere_LOD",
	"AtmoSphere",
	"Supernova",
	"SolarFlare",
	"LightShaft",
	"Shockwave",
]

## Children added under DistantProxy roots are still inside the 0.01 scale.
const PROXY_LOCAL := 100.0

## Unity Clouds_GD_Top_ramp average, darkened for wallpaper.
const GD_CLOUD_GREEN := Color(0.14, 0.24, 0.16, 0.95)


static func unlit_material(color: Color = Color(0.75, 0.78, 0.85), emission: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.5
	return mat


static func instantiate_gltf(path: String, scale: float = DISTANT_PROXY_SCALE) -> Node3D:
	var root := Node3D.new()
	var res: Resource = load(path)
	if res is PackedScene:
		var inst: Node = (res as PackedScene).instantiate()
		root.add_child(inst)
		root.scale = Vector3.ONE * scale
		_strip_unsupported_fx(inst)
		_fix_materials_recursive(inst)
		return root
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 80.0
	sm.height = 160.0
	mi.mesh = sm
	mi.material_override = unlit_material(Color(1.0, 0.0, 1.0))
	root.add_child(mi)
	push_warning("MeshLoader: missing glTF %s" % path)
	return root


static func make_sun_body(radius_m: float = 1850.0) -> Node3D:
	## Photosphere only — deeper orange (no sunspot texture / ramp “vomit”).
	var root := Node3D.new()
	var core := make_emissive_sphere(radius_m, Color(1.0, 0.48, 0.12))
	core.name = "SunSurface"
	var core_mat := core.material_override as StandardMaterial3D
	core_mat.albedo_color = Color(1.0, 0.52, 0.14)
	core_mat.emission = Color(1.0, 0.38, 0.05)
	core_mat.emission_energy_multiplier = 26.0
	root.add_child(core)
	return root


static func make_quantum_moon_body(radius_m: float = 110.0) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius_m
	sm.height = radius_m * 2.0
	mi.mesh = sm
	var mat := unlit_material(Color(0.55, 0.58, 0.65))
	var tex: Texture2D = load("res://assets/textures/Clouds_QM_Top_d.png") as Texture2D
	if tex:
		mat.albedo_texture = tex
		mat.albedo_color = Color(0.7, 0.72, 0.78)
	mi.material_override = mat
	mi.name = "QuantumMoonBody"
	root.add_child(mi)
	return root


static func repair_giants_deep(gd_body: Node3D, sharp: bool = false) -> void:
	## Soft green bands from the map. Orbit view uses the unsmeared diffuse on a finer shell.
	var band: Texture2D = null
	if sharp:
		band = load("res://assets/textures/Clouds_GD_Top_d.png") as Texture2D
	if band == null:
		band = load("res://assets/textures/Clouds_GD_Top_soft.png") as Texture2D
	if band == null:
		band = load("res://assets/textures/Clouds_GD_Top_d.png") as Texture2D
	for mi in _collect_mesh_instances(gd_body):
		var nm := String(mi.name)
		if "Cloud" not in nm:
			continue
		if "Hurricane" in nm or "Cyclone" in nm:
			mi.visible = false
			continue
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color = Color(0.38, 0.48, 0.36)
		if band:
			mat.albedo_texture = band
			mat.uv1_scale = Vector3(1.0, 1.6, 1.0)
		mat.emission_enabled = false
		mi.material_override = mat


static func repair_dark_bramble(db_body: Node3D) -> void:
	## Opaque vines + glowing seed-hole fog/lights in the center openings.
	for mi in _collect_mesh_instances(db_body):
		var nm := String(mi.name)
		if "Fog" in nm or "Volum" in nm:
			_style_db_hole_glow(mi)
			continue
		var count := mi.get_surface_override_material_count()
		if count == 0 and mi.mesh:
			count = mi.mesh.get_surface_count()
		for i in count:
			var existing := mi.get_active_material(i)
			var sm := StandardMaterial3D.new()
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			sm.albedo_color = Color(0.55, 0.7, 0.65, 1.0)
			if existing is StandardMaterial3D:
				var src := existing as StandardMaterial3D
				if src.albedo_texture:
					sm.albedo_texture = src.albedo_texture
				sm.albedo_color = Color(src.albedo_color.r, src.albedo_color.g, src.albedo_color.b, 1.0)
			sm.albedo_color.a = 1.0
			mi.set_surface_override_material(i, sm)
		var mo := StandardMaterial3D.new()
		mo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mo.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mo.cull_mode = BaseMaterial3D.CULL_DISABLED
		mo.albedo_color = Color(0.5, 0.65, 0.58, 1.0)
		if mi.get_active_material(0) is StandardMaterial3D:
			var a0 := mi.get_active_material(0) as StandardMaterial3D
			if a0.albedo_texture:
				mo.albedo_texture = a0.albedo_texture
			mo.albedo_color = Color(a0.albedo_color.r, a0.albedo_color.g, a0.albedo_color.b, 1.0)
		mi.material_override = mo
	# Soft lights inside the seed openings (proxy-local metres before 0.01 scale).
	_add_db_hole_lights(db_body)


static func _style_db_hole_glow(mi: MeshInstance3D) -> void:
	## Swamp green-yellow, tighter than the stock fog sphere.
	mi.scale = Vector3.ONE * 0.55
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.55, 0.72, 0.22, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.85, 0.2)
	mat.emission_energy_multiplier = 3.2
	var existing := mi.get_active_material(0)
	if existing is StandardMaterial3D and (existing as StandardMaterial3D).albedo_texture:
		mat.albedo_texture = (existing as StandardMaterial3D).albedo_texture
	mi.material_override = mat


static func _add_db_hole_lights(db_body: Node3D) -> void:
	## Compact swamp glow in the seed openings only.
	if db_body.get_node_or_null("SeedHoleLights"):
		return
	var root := Node3D.new()
	root.name = "SeedHoleLights"
	db_body.add_child(root)
	var offsets := [
		Vector3(0.0, 0.0, 0.0),
		Vector3(12000.0, 5000.0, -8000.0),
		Vector3(-10000.0, -4000.0, 11000.0),
	]
	for i in offsets.size():
		var light := OmniLight3D.new()
		light.name = "HoleLight_%d" % i
		light.position = offsets[i]
		light.light_color = Color(0.65, 0.8, 0.25)
		light.light_energy = 4.5 if i == 0 else 2.8
		light.omni_range = 22000.0
		light.omni_attenuation = 1.8
		root.add_child(light)


static func repair_volcanic_moon(bh_body: Node3D, detailed: bool = false) -> Node3D:
	## Keep DistantProxy LavaSphere + BakedTerrain. Mesh ±100 × scale 85.3 × 0.01 → ~85m (no extra ×100).
	var body := find_node_by_name(bh_body, "VolcanicMoon_Body")
	if body == null:
		push_warning("MeshLoader: VolcanicMoon_Body missing")
		return null

	var lava := find_node_by_name(body, "LavaSphere")
	if lava:
		_style_lava_sphere(lava, detailed)

	var rock := find_node_by_name(body, "BakedTerrain_VM_Proxy_Base")
	if rock:
		_style_vm_rock(rock, detailed)
	else:
		push_warning("MeshLoader: BakedTerrain_VM_Proxy_Base missing — volcano crust absent")
	return body


static func _style_lava_sphere(node: Node3D, detailed: bool = false) -> void:
	## Unity Effects_VM_Lava_mat HDR emission (1.99, 0.15, 0). No rock albedo (that read as yellow).
	var detail: Texture2D = null
	if detailed:
		detail = load("res://assets/textures/Terrain_VM_RockDetail_d.png") as Texture2D
	if detail == null:
		detail = load("res://assets/textures/LOD_Terrain_VM_RockDetail_d.png") as Texture2D
	if detail == null:
		detail = load("res://assets/textures/Terrain_VM_RockDetail_d.png") as Texture2D
	if detailed:
		node.scale *= 1.15
	else:
		# Satellite lava sits deeper in the rock. A larger sphere raises the fill.
		node.scale *= 1.3
	for mi in _collect_mesh_instances(node):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.28, 0.04) if detailed else Color(1.0, 0.18, 0.02)
		mat.emission_enabled = true
		mat.emission = Color(1.99, 0.22, 0.02) if detailed else Color(1.99, 0.15, 0.0)
		mat.emission_energy_multiplier = 64.0 if detailed else 48.0
		if detail:
			mat.emission_texture = detail
			mat.uv1_scale = Vector3(3.0, 2.2, 1.0) if detailed else Vector3(5.0, 3.0, 1.0)
		mi.material_override = mat


static func _style_vm_rock(node: Node3D, detailed: bool = false) -> void:
	## Dark ash/obsidian volcanoes (not lava-colored). Orbit view keeps the rock detail.
	var ash: Texture2D = load("res://assets/textures/Terrain_VM_Ash_d.png") as Texture2D
	var obsidian: Texture2D = load("res://assets/textures/Terrain_VM_Obsidian_d.png") as Texture2D
	var detail: Texture2D = load("res://assets/textures/Terrain_VM_RockDetail_d.png") as Texture2D if detailed else null
	for mi in _collect_mesh_instances(node):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.22, 0.16, 0.14)
		if detailed and detail:
			mat.albedo_texture = detail
			mat.albedo_color = Color(0.42, 0.32, 0.28)
			mat.uv1_scale = Vector3(2.4, 2.4, 1.0)
			mat.emission_enabled = false
		elif ash:
			mat.albedo_texture = ash
			mat.albedo_color = Color(0.45, 0.38, 0.34)
			mat.emission_enabled = false
		elif obsidian:
			mat.albedo_texture = obsidian
			mat.albedo_color = Color(0.35, 0.3, 0.28)
			mat.emission_enabled = false
		else:
			mat.emission_enabled = false
		mi.material_override = mat


static var _gd_cloud_hi: ArrayMesh
static var _bh_crust_mat: ShaderMaterial


static func tone_opc(root: Node3D) -> void:
	## Sandstone reads blown-out unshaded. Keep it solid and a little darker.
	if root == null:
		return
	for mi in _collect_mesh_instances(root):
		if mi.material_override is StandardMaterial3D:
			mi.material_override = _dim_opc_mat(mi.material_override as StandardMaterial3D)
		var count := mi.get_surface_override_material_count()
		if count == 0 and mi.mesh:
			count = mi.mesh.get_surface_count()
		for i in count:
			var existing := mi.get_surface_override_material(i)
			if existing == null and mi.mesh:
				existing = mi.mesh.surface_get_material(i)
			if existing is StandardMaterial3D:
				mi.set_surface_override_material(i, _dim_opc_mat(existing as StandardMaterial3D))


static func _dim_opc_mat(src: StandardMaterial3D) -> StandardMaterial3D:
	var mat := src.duplicate() as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var alb := src.albedo_color
	mat.albedo_color = Color(alb.r * 0.76, alb.g * 0.74, alb.b * 0.72, 1.0)
	if mat.emission_enabled:
		mat.emission_energy_multiplier *= 0.4
	return mat


static func open_gd_storm_volume(root: Node3D) -> void:
	## Opaque core plus a thinner outer shell so storm light can sit inside the clouds.
	var cloud := find_node_by_name(root, "CloudsTopLayer_GD__1_")
	if cloud == null or cloud.get_node_or_null("CloudShell") != null:
		return
	var mi := find_mesh_instance(cloud)
	if mi == null or mi.mesh == null:
		return
	var tex: Texture2D = null
	var uv := Vector3(1.0, 1.6, 1.0)
	if mi.material_override is StandardMaterial3D:
		var src := mi.material_override as StandardMaterial3D
		tex = src.albedo_texture
		uv = src.uv1_scale
	elif mi.material_override is ShaderMaterial:
		var sm := mi.material_override as ShaderMaterial
		var param: Variant = sm.get_shader_parameter("albedo_texture")
		if param is Texture2D:
			tex = param as Texture2D
	mi.scale = Vector3.ONE * 0.82
	var shell := mi.duplicate() as MeshInstance3D
	shell.name = "CloudShell"
	shell.scale = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color = Color(0.28, 0.36, 0.28, 0.48)
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = uv
	mat.render_priority = 2
	shell.material_override = mat
	cloud.add_child(shell)


static func apply_gd_storm_cloud(root: Node3D) -> ShaderMaterial:
	## Opaque cloud. Storms are a soft glow in the shader, under the surface.
	var cloud := find_node_by_name(root, "CloudsTopLayer_GD__1_")
	if cloud == null:
		return null
	var mi := find_mesh_instance(cloud)
	if mi == null:
		return null
	var tex: Texture2D = null
	var uv := Vector3(1.0, 1.6, 1.0)
	var tint := Color(0.38, 0.48, 0.36)
	if mi.material_override is StandardMaterial3D:
		var src := mi.material_override as StandardMaterial3D
		tex = src.albedo_texture
		uv = src.uv1_scale
		tint = src.albedo_color
	elif mi.material_override is ShaderMaterial:
		var prev := mi.material_override as ShaderMaterial
		var param: Variant = prev.get_shader_parameter("albedo_texture")
		if param is Texture2D:
			tex = param as Texture2D
	if tex == null:
		tex = load("res://assets/textures/Clouds_GD_Top_d.png") as Texture2D
	var shader := load("res://shaders/gd_cloud.gdshader") as Shader
	if shader == null:
		return null
	var sm := ShaderMaterial.new()
	sm.shader = shader
	if tex:
		sm.set_shader_parameter("albedo_tex", tex)
	sm.set_shader_parameter("albedo_tint", Vector3(0.07, 0.18, 0.045))
	sm.set_shader_parameter("uv_scale", Vector2(uv.x, uv.y))
	var count := mi.get_surface_override_material_count()
	for i in count:
		mi.set_surface_override_material(i, null)
	mi.material_override = sm
	return sm


static func refine_gd_atmosphere(root: Node3D) -> void:
	## Finer outer cloud only. Cyclones, fog, and the inner atmosphere stay out.
	hide_nodes_matching(root, PackedStringArray(["Hurricane", "Cyclone", "Water", "Island"]))
	var cloud := find_node_by_name(root, "CloudsTopLayer_GD__1_")
	if cloud == null:
		return
	var mi := find_mesh_instance(cloud)
	if mi == null or mi.mesh == null:
		return
	if _gd_cloud_hi == null:
		_gd_cloud_hi = _subdivide_sphere(mi.mesh, 2)
	mi.mesh = _gd_cloud_hi


static func _subdivide_sphere(mesh: Mesh, levels: int) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if uvs.size() != verts.size():
		uvs = PackedVector2Array()
		uvs.resize(verts.size())
	for _level in levels:
		var built: Array = _subdivide_sphere_once(verts, uvs, indices)
		verts = built[0] as PackedVector3Array
		uvs = built[1] as PackedVector2Array
		indices = built[2] as PackedInt32Array
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in verts.size():
		normals[i] = verts[i].normalized()
	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = verts
	out_arrays[Mesh.ARRAY_NORMAL] = normals
	out_arrays[Mesh.ARRAY_TEX_UV] = uvs
	out_arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
	return out


static func _subdivide_sphere_once(
	verts: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> Array:
	var mid: Dictionary = {}
	var nv := verts.duplicate()
	var nu := uvs.duplicate()
	var ni := PackedInt32Array()
	ni.resize(indices.size() * 4)
	var w := 0
	var t := 0
	while t + 2 < indices.size():
		var i0 := indices[t]
		var i1 := indices[t + 1]
		var i2 := indices[t + 2]
		var a := _sphere_mid(verts, uvs, nv, nu, mid, i0, i1)
		var b := _sphere_mid(verts, uvs, nv, nu, mid, i1, i2)
		var c := _sphere_mid(verts, uvs, nv, nu, mid, i2, i0)
		ni[w] = i0
		ni[w + 1] = a
		ni[w + 2] = c
		ni[w + 3] = i1
		ni[w + 4] = b
		ni[w + 5] = a
		ni[w + 6] = i2
		ni[w + 7] = c
		ni[w + 8] = b
		ni[w + 9] = a
		ni[w + 10] = b
		ni[w + 11] = c
		w += 12
		t += 3
	return [nv, nu, ni]


static func _sphere_mid(
	verts: PackedVector3Array,
	uvs: PackedVector2Array,
	nv: PackedVector3Array,
	nu: PackedVector2Array,
	mid: Dictionary,
	ia: int,
	ib: int
) -> int:
	var crosses := _uv_crosses(uvs[ia], uvs[ib])
	var lo := mini(ia, ib)
	var hi := maxi(ia, ib)
	var key := Vector2i(lo, hi)
	# A seam edge needs its own midpoint per triangle. One shared UV zig-zags pole to pole.
	if not crosses and mid.has(key):
		return int(mid[key])
	var p := (verts[ia] + verts[ib]) * 0.5
	var target := (verts[ia].length() + verts[ib].length()) * 0.5
	if p.length_squared() > 0.000001 and target > 0.0:
		p = p.normalized() * target
	var uv := _mid_uv(uvs[ia], uvs[ib])
	var idx := nv.size()
	nv.append(p)
	nu.append(uv)
	if not crosses:
		mid[key] = idx
	return idx


static func _uv_crosses(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) > 0.5 or absf(a.y - b.y) > 0.5


static func _mid_uv(a: Vector2, b: Vector2) -> Vector2:
	var bb := b
	if absf(bb.x - a.x) > 0.5:
		bb.x += -1.0 if bb.x > a.x else 1.0
	if absf(bb.y - a.y) > 0.5:
		bb.y += -1.0 if bb.y > a.y else 1.0
	# Leave the result outside 0–1. Repeat sampling wraps it; folding it back opens the seam.
	return (a + bb) * 0.5


static func prepare_brittle_hollow_orbit(root: Node3D) -> ShaderMaterial:
	## Full ice, and a shared crust shader so the outer plates aren't one stripe texture.
	var ice: Texture2D = load("res://assets/textures/Terrain_BH_Ice_v2_d.png") as Texture2D
	if _bh_crust_mat == null:
		var side: Texture2D = load("res://assets/textures/Terrain_BH_RockSide_d.png") as Texture2D
		var top: Texture2D = load("res://assets/textures/Terrain_BH_RockTop_d.png") as Texture2D
		var shader := load("res://shaders/bh_crust.gdshader") as Shader
		if side and top and shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("side_tex", side)
			mat.set_shader_parameter("top_tex", top)
			_bh_crust_mat = mat
	_swap_bh_ice(root, ice)
	return _bh_crust_mat


static func _swap_bh_ice(node: Node, ice: Texture2D) -> void:
	if ice and node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var hint := _material_name_hint(mi)
		if "Glacier" in hint or "Ice" in String(mi.name):
			var count := mi.mesh.get_surface_count() if mi.mesh else 0
			for i in count:
				var existing := mi.get_surface_override_material(i)
				if existing == null and mi.mesh:
					existing = mi.mesh.surface_get_material(i)
				if existing is StandardMaterial3D:
					var sm := (existing as StandardMaterial3D).duplicate() as StandardMaterial3D
					sm.albedo_texture = ice
					mi.set_surface_override_material(i, sm)
	for c in node.get_children():
		_swap_bh_ice(c, ice)


static func lock_brittle_crust(root: Node3D, mat: ShaderMaterial) -> void:
	if mat == null:
		return
	_lock_brittle_crust(root, mat)


static func _lock_brittle_crust(node: Node, mat: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var hint := _material_name_hint(mi)
		if "RockGeode" in hint or "RockGeode" in String(mi.name):
			var count := mi.get_surface_override_material_count()
			for i in count:
				mi.set_surface_override_material(i, null)
			mi.material_override = mat
	for c in node.get_children():
		_lock_brittle_crust(c, mat)


static func _collect_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(_collect_mesh_instances(c))
	return out


static func collect_named(node: Node, target: String, out: Array[Node3D]) -> void:
	if node.name == target and node is Node3D:
		out.append(node as Node3D)
	for c in node.get_children():
		collect_named(c, target, out)


## Horizontal reach from origin to the outside of the node's meshes (XZ).
static func radial_reach_xz(origin: Vector3, node: Node3D) -> float:
	var merged: Variant = null
	for mi in _collect_mesh_instances(node):
		if mi.mesh == null:
			continue
		var box: AABB = mi.global_transform * mi.mesh.get_aabb()
		merged = box if merged == null else (merged as AABB).merge(box)
	if merged == null:
		var fallback := node.global_position - origin
		fallback.y = 0.0
		return fallback.length()
	var aabb := merged as AABB
	var flat := aabb.get_center() - origin
	flat.y = 0.0
	return flat.length() + maxf(aabb.size.x, aabb.size.z) * 0.5


static func find_node_by_name(node: Node, target: String) -> Node3D:
	if node.name == target and node is Node3D:
		return node as Node3D
	for c in node.get_children():
		var found := find_node_by_name(c, target)
		if found:
			return found
	return null


static func strip_map_interiors(root: Node) -> void:
	## Drop map-scale interiors that never read from the isometric camera.
	## Timber Hearth has no separate interior nodes (village is the surface mesh).
	## Brittle Hollow: hanging city, undercrust, and the broken copy of a fragment
	## when an intact sibling is still there. Hollow's Lantern is left alone.
	var doomed: Array[Node] = []
	_collect_map_interiors(root, doomed)
	for n in doomed:
		if not is_instance_valid(n):
			continue
		var parent := n.get_parent()
		if parent:
			parent.remove_child(n)
		n.queue_free()


static func _collect_map_interiors(node: Node, out: Array[Node]) -> void:
	if _is_map_interior(node):
		out.append(node)
		return
	for c in node.get_children():
		_collect_map_interiors(c, out)


static func _is_map_interior(node: Node) -> bool:
	var nm := String(node.name)
	if nm == "Proxy_HangingCity" or nm == "Proxy_BH_HangingCity":
		return true
	if "Undercrust" in nm or "Interior" in nm:
		return true
	if "Dest" not in nm:
		return false
	var parent := node.get_parent()
	if parent == null:
		return false
	for sibling in parent.get_children():
		if sibling == node:
			continue
		if "Dest" not in String(sibling.name):
			return true
	return false


static func hide_nodes_matching(node: Node, substrings: PackedStringArray) -> void:
	## Hide matching subtrees (visible=false). Matches any substring in the node name.
	var nm := String(node.name)
	for key in substrings:
		if key != "" and key in nm:
			if node is Node3D:
				(node as Node3D).visible = false
			return
	for c in node.get_children():
		hide_nodes_matching(c, substrings)


static func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		return node as MeshInstance3D
	for c in node.get_children():
		var found := find_mesh_instance(c)
		if found:
			return found
	return null


static func _find_mesh(node: Node) -> MeshInstance3D:
	return find_mesh_instance(node)


static func _strip_unsupported_fx(node: Node) -> void:
	var to_free: Array[Node] = []
	_collect_fx_nodes(node, to_free)
	for n in to_free:
		if is_instance_valid(n):
			n.queue_free()


static func _collect_fx_nodes(node: Node, out: Array[Node]) -> void:
	var nm := String(node.name)
	for key in HIDE_NAME_MATCHES:
		if key in nm:
			out.append(node)
			return
	for c in node.get_children():
		_collect_fx_nodes(c, out)


static func _fix_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var nm := String(mi.name)
		var mat_hint := _material_name_hint(mi)
		var is_cloud := "Cloud" in nm or "Clouds_" in mat_hint
		var is_db_fog := "VolumeticFog" in nm or "VolumetricFog" in nm or "DB_Volum" in nm
		var is_gd_fog := "Fog_GD" in mat_hint or ("Fog" in nm and "GD" in nm)
		var is_db_solid := (
			not is_db_fog
			and (
				"DB_" in nm
				or "Bramble" in nm
				or "Thorn" in nm
				or "Crystal" in nm
				or "Vine" in nm
				or "Proxy_DB" in nm
				or "DB_" in mat_hint
			)
		)
		_fix_mesh_instance(mi, is_cloud, is_db_fog, is_gd_fog, mat_hint, is_db_solid)
	for c in node.get_children():
		_fix_materials_recursive(c)


static func _material_name_hint(mi: MeshInstance3D) -> String:
	var parts: PackedStringArray = []
	if mi.material_override:
		parts.append(String(mi.material_override.resource_name))
	if mi.mesh:
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m:
				parts.append(String(m.resource_name))
	return " ".join(parts)


static func _fix_mesh_instance(
	mi: MeshInstance3D,
	is_cloud: bool,
	is_db_fog: bool = false,
	is_gd_fog: bool = false,
	mat_hint: String = "",
	is_db_solid: bool = false
) -> void:
	var nm := String(mi.name)
	var count := mi.get_surface_override_material_count()
	if count == 0 and mi.mesh:
		count = mi.mesh.get_surface_count()
	for i in count:
		var existing := mi.get_active_material(i)
		if existing == null and mi.material_override:
			existing = mi.material_override
		if existing is StandardMaterial3D:
			var sm := (existing as StandardMaterial3D).duplicate() as StandardMaterial3D
			_style_surface_material(sm, nm, is_cloud, is_db_fog, is_gd_fog, mat_hint, is_db_solid)
			mi.set_surface_override_material(i, sm)
	if mi.material_override is StandardMaterial3D:
		var mo := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		_style_surface_material(mo, nm, is_cloud, is_db_fog, is_gd_fog, mat_hint, is_db_solid)
		mi.material_override = mo


static func _style_surface_material(
	sm: StandardMaterial3D,
	nm: String,
	is_cloud: bool,
	is_db_fog: bool = false,
	is_gd_fog: bool = false,
	mat_hint: String = "",
	is_db_solid: bool = false
) -> void:
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if is_db_fog:
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.albedo_color = Color(0.55, 0.72, 0.22, 0.4)
		sm.emission_enabled = true
		sm.emission = Color(0.7, 0.85, 0.2)
		sm.emission_energy_multiplier = 3.0
		return
	if is_gd_fog:
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color = Color(0, 0, 0, 0)
		return
	if is_db_solid:
		# Crystal undersides were backface-culled / alpha → double-sided opaque.
		sm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.albedo_color.a = 1.0
		return
	if not is_cloud:
		return
	sm.cull_mode = BaseMaterial3D.CULL_BACK
	var gd := "GD" in nm or "Clouds_GD" in mat_hint
	if gd:
		if "Particle" in nm or "Particle" in mat_hint:
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.albedo_color = Color(GD_CLOUD_GREEN.r, GD_CLOUD_GREEN.g, GD_CLOUD_GREEN.b, 0.55)
			return
		sm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		sm.albedo_color = Color(GD_CLOUD_GREEN.r, GD_CLOUD_GREEN.g, GD_CLOUD_GREEN.b, 1.0)
		var top: Texture2D = load("res://assets/textures/Clouds_GD_Top_soft.png") as Texture2D
		if top == null:
			top = load("res://assets/textures/Clouds_GD_Top_d.png") as Texture2D
		if top and sm.albedo_texture == null:
			sm.albedo_texture = top
	elif "QM" in nm:
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color = Color(0.55, 0.58, 0.62, 0.9)
	else:
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color = Color(sm.albedo_color.r, sm.albedo_color.g, sm.albedo_color.b, 0.9)


static func make_emissive_sphere(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = unlit_material(color, color)
	return mi
