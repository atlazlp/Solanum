extends Node

## After a supernova fade-in, bodies and their orbit lines rise from below the frame,
## inner orbits first.

const STAGGER := 0.11
const RISE := 1.0
## World units past the orbital plane before settling back down.
const OVERSHOOT := 2000.0

var _slots: Array[Dictionary] = []
var _drop := Vector3.ZERO
var _t := 0.0


func setup(slots: Array[Dictionary]) -> void:
	_slots = slots
	set_process(false)


func snap_home() -> void:
	_t = 0.0
	set_process(false)
	_paint(Vector3.ZERO)


func park() -> void:
	set_process(false)
	_drop = _drop_vector()
	_paint(_drop)


func play() -> void:
	_drop = _drop_vector()
	_t = 0.0
	_paint(_drop)
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	var done := true
	for i in _slots.size():
		var local := (_t - float(i) * STAGGER) / RISE
		if local < 1.0:
			done = false
		var u := clampf(local, 0.0, 1.0)
		_paint_slot(_slots[i], _rise_offset(u))
	if done:
		snap_home()


func _paint(offset: Vector3) -> void:
	for slot in _slots:
		_paint_slot(slot, offset)


func _paint_slot(slot: Dictionary, offset: Vector3) -> void:
	for body in slot.get("bodies", []):
		if body is BodyOrbit and is_instance_valid(body):
			(body as BodyOrbit).reveal_offset = offset
	for line in slot.get("lines", []):
		if line is OrbitLine and is_instance_valid(line):
			var ol := line as OrbitLine
			ol.position = Vector3(0.0, 2.0, 0.0) + offset
	for point in slot.get("points", []):
		if point is Node3D and is_instance_valid(point):
			var n := point as Node3D
			var home: Vector3 = n.get_meta("reveal_home", n.position)
			n.position = home + offset


func _rise_offset(u: float) -> Vector3:
	if _drop.length_squared() < 1.0:
		return Vector3.ZERO
	var past := -_drop.normalized() * OVERSHOOT
	if u < 0.76:
		var t := u / 0.76
		t = t * t * (3.0 - 2.0 * t)
		return _drop.lerp(past, t)
	var settle := (u - 0.76) / 0.24
	settle = settle * settle * (3.0 - 2.0 * settle)
	return past.lerp(Vector3.ZERO, settle)


func _drop_vector() -> Vector3:
	var down := Vector3.DOWN
	var half := 28000.0
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam:
		down = -cam.global_transform.basis.y.normalized()
		if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
			half = cam.size
	# Half-frame plus the outer orbit, so a body at the top of the view clears the bottom edge.
	return down * (half + 46000.0)
