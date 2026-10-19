class_name MoonPivotSpin
extends Node

## Spins a DistantProxy moon pivot (Attlerock / Hollow's Lantern / OPC) in local Y.
@export var period_seconds: float = 103.0
## +1 / −1 orbital direction.
@export var direction: float = 1.0

var _pivot: Node3D
var _angle: float = 0.0


func _ready() -> void:
	process_priority = -10


func setup(pivot: Node3D, period: float, dir: float = 1.0) -> void:
	_pivot = pivot
	period_seconds = period
	direction = 1.0 if dir >= 0.0 else -1.0


func _process(delta: float) -> void:
	if _pivot == null or WallpaperBus.blocks_motion() or period_seconds <= 0.0:
		return
	_angle += direction * TAU * delta * WallpaperBus.motion_scale() / period_seconds
	_pivot.rotation.y = _angle
