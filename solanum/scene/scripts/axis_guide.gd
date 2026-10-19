extends Control

## Corner legend: world axes + camera Up/Down/Left/Right for orientation talk.


func _ready() -> void:
	custom_minimum_size = Vector2(220, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var origin := Vector2(110, 100)
	# World axes projected into screen using the active camera.
	var cam := get_viewport().get_camera_3d()
	var axes: Array = [
		{"dir": Vector3.RIGHT, "col": Color(1.0, 0.25, 0.25), "name": "+X"},
		{"dir": Vector3.UP, "col": Color(0.3, 1.0, 0.35), "name": "+Y up"},
		{"dir": Vector3.BACK, "col": Color(0.35, 0.55, 1.0), "name": "+Z"},
	]
	if cam:
		for ax in axes:
			var world_tip: Vector3 = cam.global_position - cam.global_transform.basis.z * 20.0 + ax["dir"] * 8.0
			var world_o: Vector3 = cam.global_position - cam.global_transform.basis.z * 20.0
			if cam.is_position_behind(world_tip):
				continue
			var tip2 := cam.unproject_position(world_tip)
			var o2 := cam.unproject_position(world_o)
			var delta := (tip2 - o2)
			if delta.length() < 2.0:
				continue
			delta = delta.normalized() * 55.0
			_arrow(origin, origin + delta, ax["col"], ax["name"])
	# Camera screen directions (always axis-aligned in the HUD).
	_arrow(origin, origin + Vector2(0, -50), Color(1, 1, 1), "UP (screen)")
	_arrow(origin, origin + Vector2(0, 50), Color(0.7, 0.7, 0.7), "DOWN")
	_arrow(origin, origin + Vector2(-50, 0), Color(0.7, 0.7, 0.7), "LEFT")
	_arrow(origin, origin + Vector2(50, 0), Color(0.7, 0.7, 0.7), "RIGHT")
	draw_string(ThemeDB.fallback_font, Vector2(8, 16), "World: +Y = ecliptic UP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 1.0, 0.85))
	draw_string(ThemeDB.fallback_font, Vector2(8, 32), "Ecliptic = XZ plane (ocean)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.85, 1.0))


func _arrow(from: Vector2, to: Vector2, col: Color, label: String) -> void:
	draw_line(from, to, col, 2.0, true)
	var dir := (to - from).normalized()
	var n := Vector2(-dir.y, dir.x)
	draw_line(to, to - dir * 8.0 + n * 5.0, col, 2.0, true)
	draw_line(to, to - dir * 8.0 - n * 5.0, col, 2.0, true)
	draw_string(ThemeDB.fallback_font, to + dir * 6.0, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _process(_dt: float) -> void:
	queue_redraw()
