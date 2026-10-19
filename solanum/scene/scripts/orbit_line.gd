class_name OrbitLine
extends MeshInstance3D

## Camera-facing ribbon with a fixed arc-length gap.
## The ribbon is built once. The gap and the fade travel via shader uniforms.
## Opacity along the visible arc: 100% at the trailing gap edge → 0% at the leading edge.

const LINE_SHADER := preload("res://shaders/orbit_line.gdshader")

var _radius: float = 1000.0
var _width: float = 28.0
var _gap_arc_half: float = 200.0
## Extra hard-gap arc length on the trailing side only (world units).
var _gap_trail_extra: float = 0.0
var _segments: int = 384
var _follow: Node3D
var _is_ellipse: bool = false
var _semi_major: float = 0.0
var _eccentricity: float = 0.0
var _gap_angle: float = 0.0
## +1 if gap_angle increases along travel; -1 if it decreases (e.g. some moon pivots).
var _prograde_sign: float = 1.0
var _mat: ShaderMaterial


func _ready() -> void:
	# After the body and its moon have moved.
	process_priority = 20


func setup_circular(
	radius: float,
	color: Color,
	width: float = 28.0,
	gap_arc_half: float = 200.0,
	follow: Node3D = null,
	gap_trail_extra: float = 0.0
) -> void:
	_radius = radius
	_width = width
	_follow = follow
	_is_ellipse = false
	_gap_arc_half = maxf(gap_arc_half, 20.0)
	_gap_trail_extra = maxf(gap_trail_extra, 0.0)
	_ensure_mat(color)
	_build_mesh()
	position.y = 2.0


func setup_ellipse(
	semi_major: float,
	eccentricity: float,
	color: Color,
	width: float = 28.0,
	follow: Node3D = null,
	gap_arc_half: float = 280.0,
	gap_trail_extra: float = 0.0
) -> void:
	_semi_major = semi_major
	_eccentricity = clampf(eccentricity, 0.0, 0.99)
	_width = width
	_follow = follow
	_is_ellipse = true
	_gap_arc_half = maxf(gap_arc_half, 20.0)
	_gap_trail_extra = maxf(gap_trail_extra, 0.0)
	_ensure_mat(color)
	_build_mesh()
	position.y = 2.0


func _ensure_mat(color: Color) -> void:
	if _mat:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = LINE_SHADER
	_mat.set_shader_parameter("albedo", Color(color.r, color.g, color.b, 1.0))
	_mat.set_shader_parameter("half_width", _width * 0.5)
	_mat.render_priority = 1
	_mat.set_shader_parameter("fade", 1.0)
	material_override = _mat


func set_fade(amount: float) -> void:
	if _mat:
		_mat.set_shader_parameter("fade", clampf(amount, 0.0, 1.0))


func _process(_delta: float) -> void:
	if _follow == null or _mat == null:
		return
	var p := _follow_local_xz()
	if p.length_squared() < 0.01:
		return
	var next := atan2(p.z, p.x)
	var moved := angle_difference(_gap_angle, next)
	if absf(moved) > 0.00005:
		_prograde_sign = 1.0 if moved > 0.0 else -1.0
	_gap_angle = next
	var halves := _gap_halves_at_body()
	_mat.set_shader_parameter("gap_angle", _gap_angle)
	_mat.set_shader_parameter("prograde_sign", _prograde_sign)
	_mat.set_shader_parameter("trail_half", halves.x)
	_mat.set_shader_parameter("lead_half", halves.y)


func _follow_local_xz() -> Vector3:
	var g := _follow.global_position
	var parent_n := get_parent() as Node3D
	if parent_n == null:
		return Vector3(g.x, 0.0, g.z)
	if parent_n.name == "OrbitLines":
		if "reveal_offset" in _follow:
			g -= _follow.reveal_offset
		return Vector3(g.x, 0.0, g.z)
	var local := parent_n.to_local(g)
	return Vector3(local.x, 0.0, local.z)


func _point_on_orbit(ang: float) -> Vector3:
	if _is_ellipse:
		var a := _semi_major
		var e := _eccentricity
		var r := a * (1.0 - e * e) / (1.0 + e * cos(ang))
		return Vector3(r * cos(ang), 0.0, r * sin(ang))
	return Vector3(cos(ang) * _radius, 0.0, sin(ang) * _radius)


func _orbit_radius_at(ang: float) -> float:
	if _is_ellipse:
		var a := _semi_major
		var e := _eccentricity
		return a * (1.0 - e * e) / (1.0 + e * cos(ang))
	return _radius


## Returns (trail_half_rad, lead_half_rad). Trailing side can be wider.
func _gap_halves_at_body() -> Vector2:
	var r := maxf(_orbit_radius_at(_gap_angle), 1.0)
	var lead := clampf(_gap_arc_half / r, 0.015, 0.6)
	var trail := clampf((_gap_arc_half + _gap_trail_extra) / r, 0.015, 0.6)
	return Vector2(trail, lead)


func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_c: Vector3
	var prev_tangent: Vector3
	var prev_ang: float
	var has_prev := false
	for i in _segments + 1:
		var t := float(i) / float(_segments)
		var ang := t * TAU
		var c := _point_on_orbit(ang)
		var eps := 0.002
		var tangent := (_point_on_orbit(ang + eps) - _point_on_orbit(ang - eps))
		if tangent.length_squared() < 0.001:
			tangent = Vector3(-sin(ang), 0.0, cos(ang))
		else:
			tangent = tangent.normalized()
		if has_prev:
			_emit_quad(st, prev_c, prev_tangent, prev_ang, c, tangent, ang)
		prev_c = c
		prev_tangent = tangent
		prev_ang = ang
		has_prev = true
	mesh = st.commit()


func _emit_quad(
	st: SurfaceTool,
	a: Vector3,
	ta: Vector3,
	ang_a: float,
	b: Vector3,
	tb: Vector3,
	ang_b: float
) -> void:
	_emit(st, a, ta, ang_a, -1.0)
	_emit(st, a, ta, ang_a, 1.0)
	_emit(st, b, tb, ang_b, 1.0)
	_emit(st, a, ta, ang_a, -1.0)
	_emit(st, b, tb, ang_b, 1.0)
	_emit(st, b, tb, ang_b, -1.0)


func _emit(st: SurfaceTool, point: Vector3, tangent: Vector3, ang: float, side_sign: float) -> void:
	st.set_uv(Vector2(ang, side_sign))
	st.set_uv2(Vector2(tangent.x, tangent.z))
	st.add_vertex(point)
