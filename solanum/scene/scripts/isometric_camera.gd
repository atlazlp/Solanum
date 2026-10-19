extends Camera3D

## Classic isometric: ~35° elevation, 45° yaw. Orthographic for stable wallpaper framing.
## Orbit mode keeps that elevation and slowly circles a chosen body.
## Moves between the two poses on a smoothstep so the handoff has no velocity pop.
@export var solar_half_extent: float = 28000.0
@export var solar_distance: float = 50000.0
@export var elevation_deg: float = 35.264
@export var yaw_deg: float = 45.0

## Opposite the planet's own spin, and on a different period, so a longitude doesn't stay glued in frame.
const ORBIT_PERIOD := 180.0
const EASE_SEC := 1.35
const YAW_RAMP_SEC := 0.5

var _orbit_node: Node3D
var _frame_radius: float = 28000.0
var _yaw: float = 0.0
var _look: Vector3 = Vector3.ZERO
var _size_now: float = 28000.0
## overview | to_orbit | orbit | to_overview
var _phase: String = "overview"
var _ease_t: float = 0.0
var _yaw_blend: float = 0.0
var _from_look: Vector3 = Vector3.ZERO
var _from_yaw: float = 0.0
var _from_size: float = 28000.0
var _to_yaw: float = 0.0
var _to_size: float = 28000.0


func _ready() -> void:
	# After planets, moons, and orbit lines so the frame doesn't trail a frame behind.
	process_priority = 40
	projection = PROJECTION_ORTHOGONAL
	current = true
	_yaw = deg_to_rad(yaw_deg)
	_size_now = solar_half_extent
	set_process(false)
	_apply()


func is_orbiting() -> bool:
	return _phase != "overview"


func is_transitioning() -> bool:
	return _phase == "to_orbit" or _phase == "to_overview"


func orbit_arrived() -> bool:
	return _phase == "orbit"


func orbit_target() -> Node3D:
	return _orbit_node


## 0 = satellite pose, 1 = settled on the planet.
func transition_orbit_amount() -> float:
	if _phase == "orbit":
		return 1.0
	if _phase == "overview":
		return 0.0
	var u := _ease_u()
	if _phase == "to_orbit":
		return u
	return 1.0 - u


func snap_orbit(target: Node3D, frame_radius: float) -> void:
	if target == null:
		return
	_orbit_node = target
	_frame_radius = maxf(frame_radius, 800.0)
	_phase = "orbit"
	_ease_t = EASE_SEC
	_yaw_blend = 1.0
	_look = target.global_position
	_size_now = _frame_radius
	set_process(true)
	_place(_look, _yaw, _size_now)


func begin_orbit(target: Node3D, frame_radius: float) -> void:
	if target == null:
		return
	_capture_from()
	_orbit_node = target
	_frame_radius = maxf(frame_radius, 800.0)
	_to_yaw = _yaw
	_to_size = _frame_radius
	_ease_t = 0.0
	_yaw_blend = 0.0
	_phase = "to_orbit"
	set_process(true)


func return_overview() -> void:
	if _phase == "overview":
		snap_overview()
		return
	_capture_from()
	_orbit_node = null
	_to_yaw = deg_to_rad(yaw_deg)
	_to_size = solar_half_extent
	_ease_t = 0.0
	_yaw_blend = 0.0
	_phase = "to_overview"
	set_process(true)


func snap_overview() -> void:
	_phase = "overview"
	_orbit_node = null
	_ease_t = 0.0
	_yaw_blend = 0.0
	_yaw = deg_to_rad(yaw_deg)
	_look = Vector3.ZERO
	_size_now = solar_half_extent
	set_process(false)
	_apply()


func _process(delta: float) -> void:
	if _phase == "to_orbit" or _phase == "to_overview":
		_ease(delta)
		return
	if _phase != "orbit":
		set_process(false)
		return
	if _orbit_node == null or not is_instance_valid(_orbit_node):
		snap_overview()
		return
	_yaw_blend = minf(1.0, _yaw_blend + delta / YAW_RAMP_SEC)
	_yaw -= TAU * delta / ORBIT_PERIOD * _yaw_blend
	_look = _orbit_node.global_position
	_size_now = _frame_radius
	_place(_look, _yaw, _size_now)


func _ease(delta: float) -> void:
	_ease_t += delta
	var u := _ease_u()
	var aim := Vector3.ZERO
	if _phase == "to_orbit" and _orbit_node != null and is_instance_valid(_orbit_node):
		aim = _orbit_node.global_position
	_look = _from_look.lerp(aim, u)
	_size_now = lerpf(_from_size, _to_size, u)
	_yaw = lerp_angle(_from_yaw, _to_yaw, u)
	_place(_look, _yaw, _size_now)
	if u < 1.0:
		return
	if _phase == "to_orbit":
		_phase = "orbit"
		_yaw_blend = 0.0
		_look = aim
		_size_now = _frame_radius
		_place(_look, _yaw, _size_now)
		return
	snap_overview()


func _ease_u() -> float:
	var t := clampf(_ease_t / EASE_SEC, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _capture_from() -> void:
	_from_look = _look
	_from_yaw = _yaw
	_from_size = _size_now


func _apply() -> void:
	_place(Vector3.ZERO, deg_to_rad(yaw_deg), solar_half_extent)


func _place(target: Vector3, yaw: float, half_extent: float) -> void:
	var elev := deg_to_rad(elevation_deg)
	size = half_extent
	var dir := Vector3(
		cos(elev) * sin(yaw),
		sin(elev),
		cos(elev) * cos(yaw)
	).normalized()
	global_position = target + dir * solar_distance
	look_at(target, Vector3.UP)
	far = maxf(solar_distance * 4.0, 200000.0)
	near = 1.0
