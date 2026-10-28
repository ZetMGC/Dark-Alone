extends Node

var _checks: int = 0
var _failures: int = 0
var _capture: String = ""


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _fixture() -> Dictionary:
	var data := PreferenceStore.defaults()
	data.presentation = {"retro": false, "ambience": 0.15, "detail": "native"}
	data.camera = {"sensitivity": 1.6, "transition": 0.8}
	data.book = {"motion": "reduced", "page_volume": 0.2}
	data.display["size"] = [1024, 640]
	return data


func _main(store: PreferenceStore, enabled: bool = true) -> Node:
	var entry := str(ProjectSettings.get_setting("application/run/main_scene")) if "--default-entry" in OS.get_cmdline_user_args() else "res://scenes/main/main.tscn"
	var main := (load(entry) as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = enabled
	main.preference_store = store
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	return main


func _clean(store: PreferenceStore) -> void:
	for suffix in [".tmp", ""]:
		var path: String = store.get_path() + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _run() -> void:
	get_tree().create_timer(25).timeout.connect(func() -> void:
		printerr("FAIL: preferences timed out")
		get_tree().quit(1)
	)
	var mode := ""
	var directory := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preference-probe="):
			mode = arg.trim_prefix("--preference-probe=")
		if arg.begins_with("--preference-directory="):
			directory = arg.trim_prefix("--preference-directory=")
		if arg.begins_with("--capture-dir="):
			_capture = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(_capture)
	if not mode.is_empty():
		await _probe(mode, directory)
		return
	var store := PreferenceStore.new("user://preference_tests/unit_" + str(Time.get_ticks_usec()))
	_test_store(store)
	await _test_main(store)
	await _test_default_entry(store)
	_clean(store)
	print("%s: preferences, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _probe(mode: String, directory: String) -> void:
	if not directory.begins_with("user://preference_tests/process_") or ".." in directory:
		_expect(false, "Probe restricted to test namespace")
	else:
		var store := PreferenceStore.new(directory)
		if mode == "write":
			_expect(not FileAccess.file_exists(store.get_path()), "Fresh process fixture")
			var data := _fixture()
			data.display.fullscreen = "--preference-graphics" in OS.get_cmdline_user_args()
			_expect(store.save_preferences(data), "Write settings in first process")
		elif mode == "read":
			var main := _main(store)
			await get_tree().process_frame
			await get_tree().process_frame
			_expect(is_equal_approx(main.get_node("Presentation").get_ambience_gain(), 0.15) and main.get_node("Presentation").get_image_detail() == &"native", "New process applies sound and image detail")
			_expect(is_equal_approx(main.get_node("AnchorCamera").get_preferences().sensitivity, 1.6) and JournalPanel.motion_mode == &"reduced", "New process applies camera and book")
			_expect(is_equal_approx(main.get_node("NavigationHUD/%AmbienceVolume").value, 0.15), "Actual menu reflects disk preferences")
			if "--preference-graphics" in OS.get_cmdline_user_args():
				_expect(main.get_node("DisplaySettings").is_fullscreen(), "New graphical process restores fullscreen")
			get_tree().current_scene = null
			main.queue_free()
			await get_tree().process_frame
			_clean(store)
		else:
			_expect(false, "Known probe phase")
	print("%s: preference probe %s, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", mode, _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_store(store: PreferenceStore) -> void:
	var data := _fixture()
	_expect(store.validate(PreferenceStore.defaults()) and store.load_preferences().is_empty(), "Defaults valid, fresh store empty")
	var cases: Array[Dictionary] = []
	for index in 12:
		var bad := data.duplicate(true)
		match index:
			0: bad.version = 2
			1: bad.version = 1.5
			2: bad.presentation.ambience = "0.5"
			3: bad.presentation.ambience = NAN
			4: bad.presentation.detail = "unknown"
			5: bad.camera.sensitivity = 8
			6: bad.book.motion = "instant"
			7: bad.book.page_volume = -1
			8: bad.display["size"] = [0, 720]
			9: bad.display["size"] = [1280.5, 720]
			10: bad.display.monitor = -1
			11: bad.display.fullscreen = "yes"
		cases.append(bad)
	for bad in cases:
		_expect(not store.validate(bad), "Malformed preferences rejected atomically")
	_expect(store.save_preferences(data) and store.load_preferences() == data, "Preference roundtrip")
	_write(store.get_path() + ".tmp", "{interrupted")
	_expect(store.load_preferences() == data, "Interrupted temporary file ignored")
	DirAccess.remove_absolute(store.get_path() + ".tmp")
	DirAccess.make_dir_absolute(store.get_path() + ".tmp")
	var original := FileAccess.get_file_as_string(store.get_path())
	_expect(not store.save_preferences(PreferenceStore.defaults()) and FileAccess.get_file_as_string(store.get_path()) == original, "Write failure preserves old file")
	DirAccess.remove_absolute(store.get_path() + ".tmp")
	_write(store.get_path(), "{broken")
	_expect(store.load_preferences().is_empty() and not store.last_error.is_empty() and FileAccess.get_file_as_string(store.get_path()) == "{broken", "Corrupt file left intact")
	_write(store.get_path(), "x".repeat(PreferenceStore.MAX_BYTES + 1))
	_expect(store.load_preferences().is_empty() and "большой" in store.last_error, "Oversized file rejected")
	_expect(not PreferenceStore.new("res://unsafe").save_preferences(data), "Resource path rejected")


func _test_main(store: PreferenceStore) -> void:
	store.save_preferences(_fixture())
	var main := _main(store)
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var hud: NavigationHUD = main.get_node("NavigationHUD")
	var controller: PreferenceController = main.get_node("PreferenceController")
	_expect(not main.get_node("Presentation").is_retro_enabled() and JournalPanel.motion_mode == &"reduced", "Main restores preferences")
	hud.get_node("%ResetPreferences").pressed.emit()
	_expect(JournalPanel.motion_mode == &"reduced", "Hidden reset button rejected")
	session.open_menu()
	hud.show_settings(true)
	hud.get_node("%AmbienceVolume").value = 0.25
	hud.get_node("%LookSensitivity").value = 1.2
	await get_tree().create_timer(0.5).timeout
	var saved := store.load_preferences()
	_expect(is_equal_approx(saved.presentation.ambience, 0.25) and is_equal_approx(saved.camera.sensitivity, 1.2), "Debounced slider edits saved")
	if not _capture.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_expect(get_viewport().get_texture().get_image().save_png(_capture.path_join("preferences-menu.png")) == OK, "Capture settings status")
	if DisplayServer.get_name() != "headless":
		await _key(KEY_F11)
		controller.flush()
		_expect(store.load_preferences().display.fullscreen and main.get_node("DisplaySettings").is_fullscreen(), "F11 writes fullscreen preference")
		await _key(KEY_F11)
		var display: DisplaySettings = main.get_node("DisplaySettings")
		get_window().size = Vector2i(1024, 640)
		await get_tree().process_frame
		display.export_preferences()
		get_window().mode = Window.MODE_MAXIMIZED
		await get_tree().process_frame
		var maximized := display.export_preferences()
		_expect(maximized.maximized and maximized["size"] == [1024, 640], "Native maximize retains last windowed dimensions")
		var fallback: Dictionary = _fixture().display
		fallback.monitor = 255
		fallback["size"] = [7680, 4320]
		_expect(display.restore_preferences(fallback), "Unavailable monitor fallback accepted")
		await get_tree().process_frame
		await get_tree().process_frame
		var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
		_expect(get_window().current_screen < DisplayServer.get_screen_count() and get_window().size.x <= usable.size.x and get_window().size.y <= usable.size.y, "Restored window clamped to connected monitor")
		get_window().size = Vector2i(960, 600)
	controller.flush()
	var size_before := get_window().size
	var position_before := get_window().position
	hud.new_game_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	main = get_tree().current_scene
	controller = main.get_node("PreferenceController")
	session = main.get_node("NarrativeSession")
	hud = main.get_node("NavigationHUD")
	_expect(main.preferences_enabled and session.shift_number == 1 and is_equal_approx(main.get_node("AnchorCamera").get_preferences().sensitivity, 1.2), "New game keeps settings and injected store")
	_expect(FileAccess.file_exists(store.get_path()), "New game did not delete preference file")
	_expect(get_window().size == size_before and get_window().position == position_before, "Scene reload does not reposition window")
	session.open_menu()
	hud.show_settings(true)
	hud.get_node("%ResetPreferences").pressed.emit()
	saved = store.load_preferences()
	_expect(saved.presentation == PreferenceStore.defaults().presentation and saved.camera == PreferenceStore.defaults().camera and saved.book == PreferenceStore.defaults().book, "Explicit reset writes defaults")
	main.get_node("JournalPanel").set_page_volume(0.4)
	get_tree().current_scene = null
	main.queue_free()
	await get_tree().process_frame
	_expect(is_equal_approx(store.load_preferences().book.page_volume, 0.4), "Exit flushes pending change")
	_write(store.get_path(), "{broken")
	main = _main(store)
	_expect(main.get_node("NarrativeSession").mode == NarrativeSession.EXPLORATION and "повреждён" in main.get_node("NavigationHUD/%PreferenceStatus").text, "Bad settings file does not block game")
	_expect(FileAccess.get_file_as_string(store.get_path()) == "{broken", "Launch does not silently overwrite corrupt settings")
	get_tree().current_scene = null
	main.queue_free()
	await get_tree().process_frame
	main = _main(store, false)
	main.get_node("PreferenceController").reset_preferences()
	main.get_node("PreferenceController").flush()
	_expect(FileAccess.get_file_as_string(store.get_path()) == "{broken", "Disabled preferences reject even explicit reset API")
	get_tree().current_scene = null
	main.queue_free()
	await get_tree().process_frame


func _test_default_entry(store: PreferenceStore) -> void:
	_clean(store)
	var entry := str(ProjectSettings.get_setting("application/run/main_scene"))
	var main := (load(entry) as PackedScene).instantiate()
	_expect(main.preferences_enabled, "Shortcut entry enables persistent preferences")
	main.preference_store = store
	main.checkpoint_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	var hud: NavigationHUD = main.get_node("NavigationHUD")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	session.open_menu()
	_expect(not hud.get_node("%SettingsScroll").visible and hud.get_node("%OpenSettings").visible and hud.get_node("%Resume").visible, "Escape starts with short pause page")
	if not _capture.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture.path_join("pause-short.png"))
	hud.get_node("%OpenSettings").pressed.emit()
	_expect(hud.get_node("%SettingsScroll").visible and not hud.get_node("%Resume").visible, "Settings open as separate page")
	if not _capture.is_empty() and DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture.path_join("settings-page.png"))
	hud.get_node("%AmbienceVolume").value = 0.4
	await get_tree().create_timer(0.5).timeout
	_expect(is_equal_approx(store.load_preferences().presentation.ambience, 0.4), "Default entry actually saves preference edits")
	await _key(KEY_ESCAPE)
	_expect(session.mode == NarrativeSession.MENU and not hud.get_node("%SettingsScroll").visible, "Escape from settings returns to pause without resuming game")
	await _key(KEY_ESCAPE)
	_expect(session.mode == NarrativeSession.EXPLORATION, "Second Escape resumes game")
	get_tree().current_scene = null
	main.queue_free()
	await get_tree().process_frame
	main = (load(entry) as PackedScene).instantiate()
	main.preference_store = store
	main.checkpoint_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	_expect(is_equal_approx(main.get_node("Presentation").get_ambience_gain(), 0.4), "Reopening actual default scene restores saved settings")
	get_tree().current_scene = null
	main.queue_free()
	await get_tree().process_frame
