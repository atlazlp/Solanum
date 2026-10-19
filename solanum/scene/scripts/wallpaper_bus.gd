extends Node

signal paused_changed(paused: bool)
signal time_scale_changed(scale: float)
signal qm_host_changed(host: String)
signal mode_changed(mode: String)
signal supernova_requested

const MODE_SOLAR := "solar"

const SLUG_TO_HOST := {
	"timber-hearth": "timber_hearth",
	"hourglass-twins": "ember_twin",
	"brittle-hollow": "brittle_hollow",
	"giants-deep": "giants_deep",
	"dark-bramble": "dark_bramble",
}

const QM_HOST_CYCLE := [
	"timber_hearth",
	"ember_twin",
	"brittle_hollow",
	"giants_deep",
	"dark_bramble",
]

var paused: bool = false
## Freeze orbits without dropping the render rate. The camera ease uses this.
var sim_frozen: bool = false
var time_scale: float = 1.0
## Eases to 0 on pause and back to 1 on play so the visualiser can follow.
var speed_mul: float = 1.0
var _speed_target: float = 1.0
var _pause_wanted: bool = false
const SPEED_RAMP_SEC := 0.32
var mode: String = MODE_SOLAR
var qm_host: String = "timber_hearth"
var supernova_active: bool = false
var _fps_before_pause: int = 0


func pause() -> void:
	if _pause_wanted:
		return
	_pause_wanted = true
	_speed_target = 0.0


func resume() -> void:
	if not _pause_wanted and not paused:
		return
	_pause_wanted = false
	_speed_target = 1.0
	if paused:
		paused = false
		Engine.max_fps = _fps_before_pause
		paused_changed.emit(paused)


func tick_speed(delta: float) -> void:
	var step := delta / SPEED_RAMP_SEC
	if speed_mul < _speed_target:
		speed_mul = minf(_speed_target, speed_mul + step)
	elif speed_mul > _speed_target:
		speed_mul = maxf(_speed_target, speed_mul - step)
	if _pause_wanted and speed_mul <= 0.001 and not paused:
		speed_mul = 0.0
		paused = true
		_fps_before_pause = Engine.max_fps
		Engine.max_fps = 8
		paused_changed.emit(paused)


func motion_scale() -> float:
	if sim_frozen:
		return 0.0
	return time_scale * speed_mul


func toggle_pause() -> void:
	if paused:
		resume()
	else:
		pause()


func blocks_motion() -> bool:
	return paused or sim_frozen


func set_sim_frozen(frozen: bool) -> void:
	sim_frozen = frozen


func set_time_scale(scale: float) -> void:
	time_scale = maxf(scale, 0.0)
	time_scale_changed.emit(time_scale)


func set_qm_host(host_or_slug: String) -> void:
	var host := host_or_slug
	if SLUG_TO_HOST.has(host_or_slug):
		host = SLUG_TO_HOST[host_or_slug]
	if host == qm_host:
		return
	qm_host = host
	qm_host_changed.emit(qm_host)


func set_mode(new_mode: String) -> void:
	if new_mode != MODE_SOLAR and new_mode != "solar":
		push_warning("WallpaperBus: unknown mode '%s'" % new_mode)
		return
	if mode == MODE_SOLAR:
		return
	mode = MODE_SOLAR
	mode_changed.emit(mode)


func cycle_qm_host() -> void:
	var idx := QM_HOST_CYCLE.find(qm_host)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + 1) % QM_HOST_CYCLE.size()
	set_qm_host(QM_HOST_CYCLE[idx])


func apply_slug(slug: String) -> void:
	set_qm_host(slug)


func trigger_supernova() -> void:
	if supernova_active:
		return
	supernova_requested.emit()
