extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/VBox/Label
@onready var _hide_btn: Button = $Panel/VBox/HideButton
@onready var _collapsed_btn: Button = $CollapsedButton

var _expanded: bool = true


func _ready() -> void:
	WallpaperBus.paused_changed.connect(func(_p): _refresh())
	WallpaperBus.time_scale_changed.connect(func(_s): _refresh())
	WallpaperBus.qm_host_changed.connect(func(_h): _refresh())
	WallpaperBus.mode_changed.connect(func(_m): _refresh())
	WallpaperBus.supernova_requested.connect(_refresh)
	if _hide_btn:
		_hide_btn.pressed.connect(_collapse)
	if _collapsed_btn:
		_collapsed_btn.pressed.connect(_expand)
	_apply_expanded()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_H:
			_toggle_expanded()
			get_viewport().set_input_as_handled()
		KEY_P:
			WallpaperBus.toggle_pause()
			get_viewport().set_input_as_handled()
		KEY_Q:
			WallpaperBus.cycle_qm_host()
			get_viewport().set_input_as_handled()
		KEY_N:
			WallpaperBus.trigger_supernova()
			get_viewport().set_input_as_handled()
			_refresh()
		KEY_EQUAL, KEY_KP_ADD:
			WallpaperBus.set_time_scale(WallpaperBus.time_scale * 2.0)
			get_viewport().set_input_as_handled()
		KEY_MINUS, KEY_KP_SUBTRACT:
			WallpaperBus.set_time_scale(maxf(WallpaperBus.time_scale * 0.5, 0.125))
			get_viewport().set_input_as_handled()


func _toggle_expanded() -> void:
	if _expanded:
		_collapse()
	else:
		_expand()


func _collapse() -> void:
	_expanded = false
	_apply_expanded()


func _expand() -> void:
	_expanded = true
	_apply_expanded()
	_refresh()


func _apply_expanded() -> void:
	if _panel:
		_panel.visible = _expanded
	if _collapsed_btn:
		_collapsed_btn.visible = not _expanded


func _refresh() -> void:
	if _label == null or not _expanded:
		return
	_label.text = (
		"Quantum Moon Wallpaper (debug)\n"
		+ "mode: %s\n" % WallpaperBus.mode
		+ "qm_host: %s\n" % WallpaperBus.qm_host
		+ "paused: %s\n" % str(WallpaperBus.paused)
		+ "time_scale: %s\n" % str(WallpaperBus.time_scale)
		+ "supernova: %s\n\n" % ("running" if WallpaperBus.supernova_active else "idle")
		+ "[P] pause  [Q] cycle QM host\n"
		+ "[N] supernova  [+]/[-] time scale\n"
		+ "[H] hide this panel"
	)
