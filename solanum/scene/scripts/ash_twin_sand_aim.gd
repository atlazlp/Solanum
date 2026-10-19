class_name AshTwinSandAim
extends Node

## In-game, Ash Twin's sand column always faces Ember Twin (line through HGT barycenter).
## SandColumn_Exterior is authored along local +Z under SandColumnRoot.

var _ash_body: Node3D
var _ember: Node3D
var _column_root: Node3D


func setup(ash_body: Node3D, ember_orbit: Node3D) -> void:
	_ash_body = ash_body
	_ember = ember_orbit
	_column_root = MeshLoader.find_node_by_name(ash_body, "SandColumnRoot")
	if _column_root == null:
		push_warning("AshTwinSandAim: SandColumnRoot missing")


func _process(_delta: float) -> void:
	if _ash_body == null or _ember == null:
		return
	if WallpaperBus.blocks_motion() or WallpaperBus.mode != WallpaperBus.MODE_SOLAR:
		return
	var target := _ember.global_position
	var origin := _ash_body.global_position
	if origin.distance_squared_to(target) < 1.0:
		return
	# look_at aims local -Z at target; column mesh extends in +Z → flip 180°.
	var aim := _column_root if _column_root else _ash_body
	var keep_scale := aim.scale
	aim.look_at(target, Vector3.UP)
	aim.rotate_object_local(Vector3.UP, PI)
	aim.scale = keep_scale
