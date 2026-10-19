extends Node3D

const WallpaperRuntimeScript := preload("res://scripts/wallpaper_runtime.gd")

var _env: Environment


func _ready() -> void:
	var env_node := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.01, 0.01, 0.03)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.08, 0.09, 0.12)
	_env.ambient_light_energy = 0.25
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.0
	_env.tonemap_white = 1.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.85
	_env.glow_strength = 0.9
	_env.glow_bloom = 0.45
	_env.glow_hdr_threshold = 1.0
	_env.glow_hdr_scale = 1.2
	_env.glow_normalized = true
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# One blur level. Levels 3 and 4 were extra full-screen passes.
	_env.set("glow_levels/2", 0.85)
	_env.set("glow_levels/3", 0.0)
	_env.set("glow_levels/4", 0.0)
	env_node.environment = _env
	add_child(env_node)

	var runtime = WallpaperRuntimeScript.new()
	runtime.name = "WallpaperRuntime"
	add_child(runtime)
	_fade_in()


func _fade_in() -> void:
	var cover := get_node_or_null("BootFade/Cover") as CanvasItem
	if cover == null:
		return
	cover.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_property(cover, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_drop_boot_fade)


func _drop_boot_fade() -> void:
	var layer := get_node_or_null("BootFade")
	if layer:
		layer.queue_free()
