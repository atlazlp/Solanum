class_name BodyOrbit
extends Node3D

enum OrbitType { CIRCULAR, ELLIPTICAL }

@export var orbit_type: OrbitType = OrbitType.CIRCULAR
@export var radius: float = 1000.0
@export var period_seconds: float = 300.0
@export var phase_offset_deg: float = 0.0
@export var eccentricity: float = 0.0
@export var focal_distance: float = 0.0
@export var face_primary: bool = false
## Comet DistantProxy: nucleus near origin, tails extend in local -X → keep -X anti-sunward.
@export var face_comet_tail: bool = false
## Sun Station: bottoms toward sun; platforms straddle the ecliptic (one above, one below).
@export var face_nadir: bool = false
@export var spin_period_seconds: float = 0.0

var _angle: float = 0.0
var _spin: float = 0.0
var _body: Node3D
var _nadir_rest_cleared: bool = false
## Added on top of the orbital position. The reveal wave parks bodies below the frame.
var reveal_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Move before orbit lines and the camera so the look target is this frame's position.
	process_priority = -20
	_angle = deg_to_rad(phase_offset_deg)
	_body = get_node_or_null("Body") as Node3D
	if _body == null and get_child_count() > 0:
		_body = get_child(0) as Node3D
	_place()


func _process(delta: float) -> void:
	if WallpaperBus.blocks_motion() or period_seconds <= 0.0:
		return
	var dt := delta * WallpaperBus.motion_scale()
	_angle += TAU * dt / period_seconds
	if spin_period_seconds > 0.0 and _body:
		_spin += TAU * dt / spin_period_seconds
		_body.rotation.y = _spin
	_place()


func _orbit_world_position() -> Vector3:
	return global_position - reveal_offset


func _place() -> void:
	if orbit_type == OrbitType.ELLIPTICAL:
		_place_elliptical()
	else:
		position = Vector3(cos(_angle) * radius, 0.0, sin(_angle) * radius) + reveal_offset
	if _body == null:
		return
	if face_comet_tail:
		_orient_comet_tail()
	elif face_nadir:
		_orient_nadir()
	elif face_primary:
		_body.look_at(Vector3.ZERO, Vector3.UP)


func _orient_nadir() -> void:
	## 90° tip from “racing on the ocean”:
	## - Mesh top (+Y) = outward, bottom (−Y) = toward sun (center of the track).
	## - Mesh platforms (±X) = world UP → one module above the ecliptic, one below.
	## Any leftover Unity Z=-90 on mesh children cancels this into flat racing — strip it.
	var origin := _orbit_world_position()
	if origin.length_squared() < 0.01:
		return
	# Strip leftover Unity Z=-90 from a previous play session (script hot-reload alone
	# does not rebuild solar_system, so that remapping was canceling the 90° tip).
	if _body and not _nadir_rest_cleared:
		_clear_nadir_rest_rotation(_body)
		_nadir_rest_cleared = true
		print("SunStation nadir: +Y=up, +Z=sun (sideways; sterns inward)")
	var inward := -origin.normalized()
	# Proxy_SS axes (from play-test):
	# - Y = module pair → world up (same orbital radius, one above / one below).
	# - Z = bow–stern. Sideways along the track; +Z toward sun (was outward — flip).
	var y_axis := Vector3.UP
	var z_axis := inward
	var x_axis := y_axis.cross(z_axis)
	if x_axis.length_squared() < 0.0001:
		y_axis = Vector3.FORWARD
		x_axis = y_axis.cross(z_axis)
	x_axis = x_axis.normalized()
	y_axis = z_axis.cross(x_axis).normalized()
	var keep_scale := _body.scale
	_body.global_transform = Transform3D(Basis(x_axis, y_axis, z_axis).orthonormalized(), _body.global_position)
	_body.scale = keep_scale


func _clear_nadir_rest_rotation(n: Node) -> void:
	for c in n.get_children():
		if c is Node3D:
			var n3 := c as Node3D
			n3.rotation = Vector3.ZERO
			_clear_nadir_rest_rotation(n3)




func _orient_comet_tail() -> void:
	var to_sun := -_orbit_world_position()
	if to_sun.length_squared() < 0.01:
		return
	to_sun = to_sun.normalized()
	var up := Vector3.UP
	var z_axis := to_sun.cross(up)
	if z_axis.length_squared() < 0.0001:
		up = Vector3.RIGHT
		z_axis = to_sun.cross(up)
	z_axis = z_axis.normalized()
	var y_axis := z_axis.cross(to_sun).normalized()
	var keep_scale := _body.scale
	_body.global_basis = Basis(to_sun, y_axis, z_axis)
	_body.scale = keep_scale


func _place_elliptical() -> void:
	var a := radius
	var e := eccentricity
	if e <= 0.0 and focal_distance > 0.0 and a > 0.0:
		e = clampf(focal_distance / a, 0.0, 0.99)
	var M := _angle
	var E := M
	for _i in 6:
		E = E - (E - e * sin(E) - M) / (1.0 - e * cos(E))
	var x := a * (cos(E) - e)
	var z := a * sqrt(1.0 - e * e) * sin(E)
	position = Vector3(x, 0.0, z) + reveal_offset
