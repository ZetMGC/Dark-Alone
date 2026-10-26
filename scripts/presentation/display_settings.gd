class_name DisplaySettings
extends Node
## Настройки окна; игровой прогресс не затрагивают.

static var _windowed_size: Vector2i = Vector2i(1280, 720)
static var _windowed_position: Vector2i = Vector2i.ZERO
static var _windowed_screen: int = -1
static var _return_maximized: bool = false
var _mode_control: OptionButton
var _monitor_control: OptionButton
var _refresh_timer: float = 0.0


func configure_controls(hud: NavigationHUD) -> void:
	_mode_control = hud.get_node("%DisplayMode")
	_monitor_control = hud.get_node("%DisplayMonitor")
	_mode_control.item_selected.connect(func(index: int) -> void: set_fullscreen(index == 1))
	_monitor_control.item_selected.connect(set_monitor)
	get_window().size_changed.connect(_sync_controls)
	_sync_controls()


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= 1.0:
		_refresh_timer = 0.0
		_sync_controls()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	return get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]


func set_fullscreen(enabled: bool) -> bool:
	if DisplayServer.get_name() == "headless" or get_window().is_embedded() or enabled == is_fullscreen():
		return false
	var window := get_window()
	if enabled:
		_return_maximized = window.mode == Window.MODE_MAXIMIZED
		if window.mode == Window.MODE_WINDOWED:
			_windowed_size = window.size
			_windowed_position = window.position
			_windowed_screen = window.current_screen
		window.mode = Window.MODE_FULLSCREEN
	else:
		var target_screen := window.current_screen
		window.mode = Window.MODE_WINDOWED
		_restore_window(target_screen)
		if _return_maximized:
			window.mode = Window.MODE_MAXIMIZED
	_sync_controls.call_deferred()
	return true


func set_monitor(index: int) -> bool:
	if DisplayServer.get_name() == "headless" or get_window().is_embedded() or index < 0 or index >= DisplayServer.get_screen_count():
		return false
	var window := get_window()
	if index == window.current_screen:
		return false
	var full := is_fullscreen()
	if not full and window.mode == Window.MODE_WINDOWED:
		_windowed_size = window.size
		_windowed_position = window.position
		_windowed_screen = window.current_screen
	if full:
		window.mode = Window.MODE_WINDOWED
	window.current_screen = index
	_restore_window(index)
	if full:
		window.mode = Window.MODE_FULLSCREEN
	_sync_controls.call_deferred()
	return true


func _restore_window(screen: int) -> void:
	var window := get_window()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var available := Vector2i(maxi(usable.size.x - 32, 1), maxi(usable.size.y - 64, 1))
	window.size = _windowed_size.min(available).max(window.min_size)
	var target := _windowed_position if screen == _windowed_screen else usable.position + (usable.size - window.size) / 2
	var maximum := usable.end - window.size - Vector2i(8, 8)
	window.position = target.clamp(usable.position + Vector2i(8, 32), maximum.max(usable.position + Vector2i(8, 32)))


func _sync_controls() -> void:
	if not is_instance_valid(_mode_control):
		return
	var unavailable := DisplayServer.get_name() == "headless" or get_window().is_embedded()
	_mode_control.disabled = unavailable
	_monitor_control.disabled = unavailable
	_mode_control.select(1 if is_fullscreen() else 0)
	if unavailable:
		return
	var count := DisplayServer.get_screen_count()
	if count != _monitor_control.item_count:
		_monitor_control.clear()
		for index in count:
			_monitor_control.add_item("", index)
	for index in count:
		var size := DisplayServer.screen_get_size(index)
		_monitor_control.set_item_text(index, "%d · %d × %d" % [index + 1, size.x, size.y])
	_monitor_control.select(get_window().current_screen)
