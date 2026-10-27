class_name PreferenceController
extends Node
## Связь UI-предпочтений с диском; не знает о прогрессе игры.

var _store: PreferenceStore
var _art: PresentationController
var _camera: AnchorCamera
var _book: JournalPanel
var _display: DisplaySettings
var _status: Label
var _snapshot: Dictionary = {}
var _pending: bool = false
var _quiet_seconds: float = 0
var _applying: bool = false


func configure(store: PreferenceStore, art: PresentationController, camera: AnchorCamera, book: JournalPanel, display: DisplaySettings, hud: NavigationHUD, enabled: bool, load_from_disk: bool = true) -> void:
	_store = store
	_status = hud.get_node("%PreferenceStatus")
	hud.get_node("%ResetPreferences").disabled = not enabled
	if not enabled:
		_status.text = "Запись настроек отключена для проверки."
		return
	_art = art
	_camera = camera
	_book = book
	_display = display
	var saved := _store.load_preferences() if load_from_disk else {}
	if not saved.is_empty():
		_apply(saved)
	_status.text = "Настройки сохраняются автоматически." if _store.last_error.is_empty() else _store.last_error
	_snapshot = _capture()
	art.preferences_changed.connect(_changed)
	camera.preferences_changed.connect(_changed)
	book.preferences_changed.connect(_changed)
	display.preferences_changed.connect(_changed)
	hud.get_node("%ResetPreferences").pressed.connect(func() -> void:
		if hud.get_node("%Menu").visible:
			reset_preferences()
	)


func _capture() -> Dictionary:
	return {"version": 1, "presentation": {"retro": _art.is_retro_enabled(), "ambience": _art.get_ambience_gain(), "detail": str(_art.get_image_detail())}, "camera": _camera.get_preferences(), "book": {"motion": str(JournalPanel.motion_mode), "page_volume": JournalPanel.page_volume}, "display": _display.export_preferences()}


func _apply(data: Dictionary) -> void:
	_applying = true
	_art.set_retro_enabled(data.presentation.retro)
	_art.set_ambience_gain(data.presentation.ambience)
	_art.set_image_detail(StringName(data.presentation.detail))
	_camera.set_look_sensitivity(data.camera.sensitivity)
	_camera.set_transition_duration(data.camera.transition)
	_book.set_motion_mode(StringName(data.book.motion))
	_book.set_page_volume(data.book.page_volume)
	_display.restore_preferences(data.display)
	_applying = false


func _changed() -> void:
	if _applying:
		return
	var data := _capture()
	if data == _snapshot:
		return
	_snapshot = data
	_pending = true
	_quiet_seconds = 0
	_status.text = "Сохраняем настройки…"


func reset_preferences() -> void:
	var data := PreferenceStore.defaults()
	data.display.monitor = _display.export_preferences().monitor
	_apply(data)
	_snapshot = _capture()
	_pending = true
	flush()


func flush() -> bool:
	if is_instance_valid(_display) and _display.is_inside_tree():
		var latest := _capture()
		if latest != _snapshot:
			_snapshot = latest
			_pending = true
	if not _pending:
		return true
	_pending = false
	var success := _store.save_preferences(_snapshot)
	if not success:
		_pending = true
		_quiet_seconds = -4.65
	if is_instance_valid(_status):
		_status.text = "Настройки сохранены." if success else _store.last_error
	return success


func _process(delta: float) -> void:
	if _pending:
		_quiet_seconds += delta
		if _quiet_seconds >= 0.35:
			flush()


func _exit_tree() -> void:
	flush()
