class_name QuantumMoon
extends Node3D

@export var orbit_radius: float = 1100.0
@export var period_seconds: float = 90.0

var _angle: float = 0.0
var _hosts: Dictionary = {}
var _host_nodes: Dictionary = {}
var _day_night: DayNightShade
## Approximate planet radii for eclipse umbra (game metres).
## Twins are skipped — QM never goes dark behind the Hourglass pair.
const _SHADOW_R := {
	"timber_hearth": 910.0,
	"brittle_hollow": 595.0,
	"giants_deep": 900.0,
	"dark_bramble": 450.0,
}
const _NO_ECLIPSE_HOSTS := ["ash_twin", "ember_twin", "hourglass_twins"]
## Pivot whose meshes include the moon. QM orbit must clear that reach.
const _MOON_PIVOT := {
	"timber_hearth": "Moon_Pivot",
	"brittle_hollow": "VolcanicMoon_Pivot",
}
const _MOON_CLEAR_PAD := 140.0


func setup(hosts: Dictionary, host_nodes: Dictionary, mesh: Node3D) -> void:
	_hosts = hosts
	_host_nodes = host_nodes
	for c in get_children():
		c.queue_free()
	if mesh:
		add_child(mesh)
	WallpaperBus.qm_host_changed.connect(_on_host_changed)
	_on_host_changed(WallpaperBus.qm_host)


func set_day_night(dn: DayNightShade, host_nodes: Dictionary) -> void:
	_day_night = dn
	_host_nodes = host_nodes
	_update_eclipse_planet(WallpaperBus.qm_host)


func _process(delta: float) -> void:
	if WallpaperBus.blocks_motion() or WallpaperBus.mode != WallpaperBus.MODE_SOLAR:
		return
	if period_seconds <= 0.0:
		return
	_angle += TAU * delta * WallpaperBus.motion_scale() / period_seconds
	position = Vector3(cos(_angle) * orbit_radius, 0.0, sin(_angle) * orbit_radius)


func _on_host_changed(host: String) -> void:
	orbit_radius = float(_hosts.get(host, 1100.0))
	var parent_node: Node3D = _host_nodes.get(host) as Node3D
	if parent_node == null:
		push_warning("QuantumMoon: no host node for '%s'" % host)
		return
	var keep_xform := global_transform
	if get_parent() != parent_node:
		reparent(parent_node, true)
	global_transform = keep_xform
	if host in _MOON_PIVOT:
		var reach := _moon_reach(parent_node, str(_MOON_PIVOT[host]))
		if reach > 1.0:
			orbit_radius = maxf(orbit_radius, reach + _self_radius() + _MOON_CLEAR_PAD)
	_angle = 0.0
	position = Vector3(orbit_radius, 0.0, 0.0)
	_update_eclipse_planet(host)


func _moon_reach(host_node: Node3D, pivot_name: String) -> float:
	var pivots: Array[Node3D] = []
	MeshLoader.collect_named(host_node, pivot_name, pivots)
	var reach := 0.0
	for pivot in pivots:
		if is_instance_valid(pivot):
			reach = maxf(reach, MeshLoader.radial_reach_xz(host_node.global_position, pivot))
	return reach


func _self_radius() -> float:
	return maxf(MeshLoader.radial_reach_xz(global_position, self), 80.0)


func _update_eclipse_planet(host: String) -> void:
	if _day_night == null:
		return
	if host in _NO_ECLIPSE_HOSTS:
		_day_night.set_eclipse_planet(null, 0.0)
		return
	var planet: Node3D = _host_nodes.get(host) as Node3D
	var r := float(_SHADOW_R.get(host, 400.0))
	_day_night.set_eclipse_planet(planet, r)
