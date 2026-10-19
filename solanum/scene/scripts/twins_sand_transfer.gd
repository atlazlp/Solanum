class_name TwinsSandTransfer
extends Node

## Ash ↔ Ember sand mass transfer. Sand *volume* moves continuously:
## one grows while the other shrinks — no pause at either end.
## Every 22 minutes the roles reverse (Ash full → Ember full → Ash full).

const HALF_CYCLE_SEC := 22.0 * 60.0
const FULL_CYCLE_SEC := HALF_CYCLE_SEC * 2.0
## Max sand sphere diameter vs Ember Twin mesh diameter.
const MAX_DIAMETER_FRAC := 0.75
## Empty-twin radius as a fraction of max (never fully disappears).
const MIN_RADIUS_FRAC := 0.04

## Sand-column hue, darkened so solid spheres read less washed-out.
const SAND_COLOR := Color(0.52, 0.45, 0.34)

var _ash_mi: MeshInstance3D
var _ember_mi: MeshInstance3D
var _max_radius: float = 1.0
var _min_radius: float = 0.04
var _elapsed: float = 0.0


func setup(ash_orbit: Node3D, ember_orbit: Node3D, ember_body: Node3D) -> void:
	var ember_diam := _world_mesh_diameter(ember_body)
	if ember_diam < 1.0:
		ember_diam = 600.0
		push_warning("TwinsSandTransfer: could not measure Ember Twin — using fallback diameter")
	_max_radius = ember_diam * MAX_DIAMETER_FRAC * 0.5
	_min_radius = maxf(_max_radius * MIN_RADIUS_FRAC, 1.5)

	var mat := MeshLoader.unlit_material(SAND_COLOR)
	_ash_mi = _make_unit_sphere("SandSphere", mat)
	_ember_mi = _make_unit_sphere("SandSphere", mat)
	ash_orbit.add_child(_ash_mi)
	ember_orbit.add_child(_ember_mi)
	DayNightShade.attach(ash_orbit, _ash_mi)
	DayNightShade.attach(ember_orbit, _ember_mi)
	_apply_fill(1.0)


func _process(delta: float) -> void:
	if _ash_mi == null or _ember_mi == null:
		return
	if WallpaperBus.blocks_motion() or WallpaperBus.mode != WallpaperBus.MODE_SOLAR:
		return
	_elapsed = fmod(_elapsed + delta * WallpaperBus.motion_scale(), FULL_CYCLE_SEC)
	_apply_fill(_ash_volume_fill(_elapsed))


## Ash sand volume fraction in 0..1. Ember always gets (1 - ash).
## Triangle: 1 → 0 over first 22 min, 0 → 1 over next 22 min.
func _ash_volume_fill(elapsed: float) -> float:
	if elapsed <= HALF_CYCLE_SEC:
		return 1.0 - elapsed / HALF_CYCLE_SEC
	return (elapsed - HALF_CYCLE_SEC) / HALF_CYCLE_SEC


func _apply_fill(ash_fill: float) -> void:
	var ember_fill := 1.0 - ash_fill
	_ash_mi.scale = Vector3.ONE * _radius_from_volume(ash_fill)
	_ember_mi.scale = Vector3.ONE * _radius_from_volume(ember_fill)


## Volume fraction → radius so both orbs keep changing size the whole time
## (linear radius made the empty twin look dead until late in the cycle).
func _radius_from_volume(fill: float) -> float:
	var t := clampf(fill, 0.0, 1.0)
	return lerpf(_min_radius, _max_radius, pow(t, 1.0 / 3.0))


func _make_unit_sphere(node_name: String, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	mi.mesh = sm
	mi.material_override = mat
	return mi


func _world_mesh_diameter(root: Node3D) -> float:
	var merged: Variant = null
	for mi in MeshLoader._collect_mesh_instances(root):
		if mi.mesh == null:
			continue
		var a: AABB = mi.global_transform * mi.mesh.get_aabb()
		merged = a if merged == null else (merged as AABB).merge(a)
	if merged == null:
		return 0.0
	var size: Vector3 = (merged as AABB).size
	return maxf(size.x, maxf(size.y, size.z))
