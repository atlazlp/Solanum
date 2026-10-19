class_name OrbitsData
extends RefCounted

## Radii: prefer Unity SolarSystem sockets / DistantProxy locals over handoff approximations.
## Speeds: orbits_per_22min / period_seconds_wallpaper_ref from user counts.

var raw: Dictionary = {}
var bodies: Dictionary = {}
var flavor: Dictionary = {}
var qm_hosts: Dictionary = {}


static func load_from_res(path: String = "res://data/orbits.json") -> OrbitsData:
	var data := OrbitsData.new()
	if not FileAccess.file_exists(path):
		push_error("OrbitsData: missing %s" % path)
		return data
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("OrbitsData: invalid JSON")
		return data
	data.raw = parsed
	data.bodies = data.raw.get("bodies", {})
	data.flavor = data.raw.get("optional_flavor", {})
	var qm: Dictionary = data.bodies.get("quantum_moon", {})
	var orbit: Dictionary = qm.get("orbit", {})
	data.qm_hosts = orbit.get("hosts", {})
	return data


func body(id: String) -> Dictionary:
	return bodies.get(id, {})


func period(body_id: String, fallback_key: String = "period_seconds_wallpaper_ref") -> float:
	var b: Dictionary = body(body_id)
	var orbit: Dictionary = b.get("orbit", {})
	if orbit.has(fallback_key):
		return float(orbit[fallback_key])
	if orbit.has("period_seconds_game"):
		return float(orbit["period_seconds_game"])
	if orbit.has("period_seconds_game_datamine"):
		return float(orbit["period_seconds_game_datamine"])
	return 300.0


func semi_major(body_id: String) -> float:
	var orbit: Dictionary = body(body_id).get("orbit", {})
	return float(orbit.get("semiMajorAxis", 0.0))
