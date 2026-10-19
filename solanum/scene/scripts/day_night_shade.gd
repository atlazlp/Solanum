class_name DayNightShade
extends Node

## Applies sun day/night shading to mesh materials under a body.
## Optional moon eclipse when the planet sits between the moon and the sun.

const SHADER_PATH := "res://shaders/day_night_unlit.gdshader"
const SHADER_DS_PATH := "res://shaders/day_night_unlit_doublesided.gdshader"

@export var night_level: float = 0.14
@export var day_level: float = 1.05
@export var planet_shadow_radius: float = 0.0
## When set, eclipse stops at this light instead of going nearly black.
var eclipse_floor: float = 0.0

var _root: Node3D
var _planet: Node3D
var _mats: Array[ShaderMaterial] = []
var _mat_nodes: Array[Node3D] = []
var _shader: Shader
var _shader_ds: Shader
var _skip_subtrees: PackedStringArray = []
## Cannon segments each sample the planet shadow from their own center.
var per_part_umbra: bool = false


func setup(
	root: Node3D,
	planet: Node3D = null,
	shadow_radius: float = 0.0,
	skip_subtrees: PackedStringArray = PackedStringArray()
) -> void:
	_root = root
	_planet = planet
	planet_shadow_radius = shadow_radius
	_skip_subtrees = skip_subtrees
	_shader = load(SHADER_PATH) as Shader
	_shader_ds = load(SHADER_DS_PATH) as Shader
	if _shader == null or _root == null:
		push_warning("DayNightShade: missing shader or root")
		return
	_wrap_recursive(_root)
	set_process(true)


func _wrap_recursive(n: Node) -> void:
	var nm := String(n.name)
	for skip in _skip_subtrees:
		if nm == skip:
			return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var minm := String(mi.name)
		if not ("Fog" in minm or "Volum" in minm or "Lightning" in minm or "Storm" in minm):
			_wrap_mesh_instance(mi)
	for c in n.get_children():
		_wrap_recursive(c)


func _wrap_mesh_instance(mi: MeshInstance3D) -> void:
	if mi.material_override is StandardMaterial3D:
		mi.material_override = _from_standard(mi.material_override as StandardMaterial3D)
		if mi.material_override is ShaderMaterial:
			_mats.append(mi.material_override as ShaderMaterial)
			_mat_nodes.append(mi)
	var count := mi.get_surface_override_material_count()
	if count == 0 and mi.mesh:
		count = mi.mesh.get_surface_count()
	for i in count:
		var existing := mi.get_surface_override_material(i)
		if existing == null and mi.mesh:
			existing = mi.mesh.surface_get_material(i)
		if existing is StandardMaterial3D:
			var sm := _from_standard(existing as StandardMaterial3D)
			mi.set_surface_override_material(i, sm)
			_mats.append(sm)
			_mat_nodes.append(mi)
		elif existing is ShaderMaterial:
			var sh: Shader = (existing as ShaderMaterial).shader
			if sh == _shader or sh == _shader_ds:
				_mats.append(existing as ShaderMaterial)
				_mat_nodes.append(mi)


func _from_standard(src: StandardMaterial3D) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	var double_sided := src.cull_mode == BaseMaterial3D.CULL_DISABLED
	sm.shader = _shader_ds if double_sided and _shader_ds else _shader
	# Force opaque — writing ALPHA in the shader (or a<1 albedo) made GD see-through.
	var alb := src.albedo_color
	alb.a = 1.0
	sm.set_shader_parameter("albedo_color", alb)
	if src.albedo_texture:
		sm.set_shader_parameter("albedo_texture", src.albedo_texture)
		sm.set_shader_parameter("use_albedo_texture", true)
	else:
		sm.set_shader_parameter("use_albedo_texture", false)
	if src.emission_enabled:
		sm.set_shader_parameter("emission_color", src.emission)
		sm.set_shader_parameter("emission_energy", src.emission_energy_multiplier)
		if src.emission_texture:
			sm.set_shader_parameter("emission_texture", src.emission_texture)
			sm.set_shader_parameter("use_emission_texture", true)
		else:
			sm.set_shader_parameter("use_emission_texture", false)
	else:
		sm.set_shader_parameter("emission_energy", 0.0)
		sm.set_shader_parameter("use_emission_texture", false)
	sm.set_shader_parameter("night_level", night_level)
	sm.set_shader_parameter("day_level", day_level)
	sm.set_shader_parameter("terminator_soft", 0.18)
	sm.set_shader_parameter("eclipse", 0.0)
	sm.set_shader_parameter("eclipse_floor", eclipse_floor)
	sm.set_shader_parameter("sun_position", Vector3.ZERO)
	return sm


func track(mat: ShaderMaterial) -> void:
	if mat and not _mats.has(mat):
		_mats.append(mat)
		_mat_nodes.append(_root)


var _body_fade: float = 1.0


func set_fade(amount: float) -> void:
	var next := clampf(amount, 0.0, 1.0)
	if is_equal_approx(_body_fade, next):
		return
	_body_fade = next
	for mat in _mats:
		if is_instance_valid(mat):
			mat.set_shader_parameter("body_fade", next)


func covers(body: Node3D) -> bool:
	return _root != null and body != null and (_root == body or body.is_ancestor_of(_root))


func set_light_levels(night: float, day: float) -> void:
	night_level = night
	day_level = day
	for mat in _mats:
		if is_instance_valid(mat):
			mat.set_shader_parameter("night_level", night)
			mat.set_shader_parameter("day_level", day)


func set_eclipse_floor(level: float) -> void:
	eclipse_floor = clampf(level, 0.0, 1.0)
	for mat in _mats:
		if is_instance_valid(mat):
			mat.set_shader_parameter("eclipse_floor", eclipse_floor)


func set_eclipse_planet(planet: Node3D, shadow_radius: float = -1.0) -> void:
	_planet = planet
	if shadow_radius >= 0.0:
		planet_shadow_radius = shadow_radius


## Degrees past the geometric limb before the moon is fully eclipsed (narrower umbra).
@export var eclipse_inset_deg: float = 11.0
## Soft penumbra width from limb inward toward full umbra (degrees of orbit).
@export var eclipse_penumbra_deg: float = 14.0


func _process(_delta: float) -> void:
	if _mats.is_empty():
		return
	if WallpaperBus.mode != WallpaperBus.MODE_SOLAR:
		return
	var ecl := 0.0
	var use_parts := per_part_umbra and _planet != null and planet_shadow_radius > 0.0
	if not use_parts and _planet != null and planet_shadow_radius > 0.0 and _root != null:
		ecl = _eclipse_factor(
			_root.global_position,
			_planet.global_position,
			planet_shadow_radius,
			eclipse_inset_deg,
			eclipse_penumbra_deg
		)
	var center := _root.global_position if _root else Vector3.ZERO
	var planet_pos := _planet.global_position if _planet != null else Vector3.ZERO
	for i in _mats.size():
		var mat := _mats[i]
		if not is_instance_valid(mat):
			continue
		var part_ecl := ecl
		if use_parts:
			var node := _mat_nodes[i] if i < _mat_nodes.size() else _root
			part_ecl = _geometric_umbra(_part_center(node), planet_pos, planet_shadow_radius)
		mat.set_shader_parameter("eclipse", part_ecl)
		if mat.shader and String(mat.shader.resource_path).ends_with("bh_crust.gdshader"):
			mat.set_shader_parameter("planet_center", center)


static func _eclipse_factor(
	moon_pos: Vector3,
	planet_pos: Vector3,
	planet_radius: float,
	inset_deg: float = 11.0,
	penumbra_deg: float = 14.0
) -> float:
	## Sun at origin. 0 = lit, 1 = full night. Limb is only the start of penumbra;
	## full dark needs the moon a few degrees deeper behind the planet.
	var m_len_sq := moon_pos.length_squared()
	var p_len_sq := planet_pos.length_squared()
	if m_len_sq <= p_len_sq or p_len_sq < 1.0 or planet_radius <= 0.0:
		return 0.0
	var p_len := sqrt(p_len_sq)
	var axis := planet_pos / p_len
	var along := moon_pos.dot(axis)
	if along < p_len:
		return 0.0
	var perp := (moon_pos - axis * along).length()
	# Slight cone growth past the planet.
	var limb := planet_radius * (0.92 + 0.08 * (along / p_len))
	if perp >= limb:
		return 0.0
	var orbit_r := maxf(along, 1.0)
	var inset := orbit_r * tan(deg_to_rad(inset_deg))
	var penumbra := orbit_r * tan(deg_to_rad(penumbra_deg))
	var umbra_core := maxf(limb - inset, limb * 0.2)
	var penumbra_start := minf(limb, umbra_core + penumbra)
	if perp <= umbra_core:
		return 1.0
	if perp >= penumbra_start:
		return 0.0
	return 1.0 - smoothstep(umbra_core, penumbra_start, perp)


## Sun disc used only for the cannon's geometric shadow cone.
const _SUN_RADIUS := 1850.0


static func _part_center(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			return mi.global_transform * mi.mesh.get_aabb().get_center()
	return node.global_position


## 0 lit, 1 full umbra. Soft edge is ~12% of the local cone radius.
static func _geometric_umbra(point: Vector3, planet_pos: Vector3, planet_radius: float) -> float:
	var p_len := planet_pos.length()
	if p_len < 1.0 or planet_radius <= 0.0:
		return 0.0
	var axis := planet_pos / p_len
	var along := point.dot(axis)
	if along < p_len:
		return 0.0
	var past := along - p_len
	var denom := _SUN_RADIUS - planet_radius
	var umbra_len := planet_radius * p_len / denom if denom > 1.0 else 1.0e9
	if past >= umbra_len:
		return 0.0
	var shadow_r := planet_radius * (1.0 - past / umbra_len)
	var perp := (point - axis * along).length()
	var edge := maxf(shadow_r * 0.12, 6.0)
	var inner := maxf(shadow_r - edge, 0.0)
	var outer := shadow_r + edge
	if perp <= inner:
		return 1.0
	if perp >= outer:
		return 0.0
	return 1.0 - smoothstep(inner, outer, perp)


static func attach(
	parent: Node,
	root: Node3D,
	planet: Node3D = null,
	shadow_radius: float = 0.0,
	skip_subtrees: PackedStringArray = PackedStringArray()
) -> DayNightShade:
	var dn := DayNightShade.new()
	dn.name = "DayNightShade_%s" % (root.name if root else "body")
	parent.add_child(dn)
	dn.setup(root, planet, shadow_radius, skip_subtrees)
	return dn
