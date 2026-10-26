extends Node

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	await get_tree().create_timer(0.16).timeout
	await RenderingServer.frame_post_draw if DisplayServer.get_name() != "headless" else get_tree().process_frame


func _fits(inner: Rect2, outer: Rect2) -> bool:
	return outer.grow(2.0).encloses(inner)


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			var folder := argument.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(folder)
			_expect(get_viewport().get_texture().get_image().save_png(folder.path_join("da037_" + name + ".png")) == OK, "Screenshot " + name)


func _run() -> void:
	get_tree().create_timer(40).timeout.connect(func() -> void:
		printerr("FAIL: display check timed out")
		get_tree().quit(1)
	)
	JournalPanel.motion_mode = &"off"
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	var display: DisplaySettings = main.get_node("DisplaySettings")
	var hud: NavigationHUD = main.get_node("NavigationHUD")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var journal: JournalPanel = main.get_node("JournalPanel")
	var window := get_window()
	_expect(window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and window.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "UI scales uniformly with expanded aspect")
	_expect(not display.set_monitor(-1) and not display.set_monitor(999), "Unknown monitors rejected")
	var headless := DisplayServer.get_name() == "headless"
	session.start_dialogue(&"test_guest_intro")
	session.choose_for_node(&"test_guest_intro", &"opening", &"ask_more")
	session.cancel_dialogue()
	if headless:
		_expect(not display.set_fullscreen(true) and hud.get_node("%DisplayMode").disabled, "Headless does not pretend fullscreen is supported")
	else:
		_expect(hud.get_node("%DisplayMonitor").item_count == DisplayServer.get_screen_count(), "All attached monitors listed")
		_expect("×" in hud.get_node("%DisplayMonitor").get_item_text(0), "Monitor label shows actual resolution even with one screen")
		var before_size := window.size
		var before_screen := window.current_screen
		var key := InputEventKey.new()
		key.keycode = KEY_F11
		key.pressed = true
		get_viewport().push_input(key)
		await _settle()
		_expect(display.is_fullscreen(), "F11 enters actual fullscreen")
		_expect(window.size == DisplayServer.screen_get_size(window.current_screen), "Fullscreen uses native monitor dimensions")
		_capture("fullscreen")
		key.echo = true
		get_viewport().push_input(key)
		_expect(display.is_fullscreen(), "Held F11 does not toggle repeatedly")
		for index in DisplayServer.get_screen_count():
			if index == window.current_screen:
				continue
			_expect(display.set_monitor(index), "Move fullscreen to attached monitor")
			await _settle()
			_expect(window.current_screen == index and display.is_fullscreen(), "Monitor change preserves fullscreen")
		display.set_monitor(before_screen)
		display.set_fullscreen(false)
		await _settle()
		_expect(window.mode == Window.MODE_WINDOWED and window.size == before_size, "Return restores original window size")
		_expect(not display.set_fullscreen(false), "Repeated mode request has no side effects")
		hud.get_node("%DisplayMode").item_selected.emit(1)
		await _settle()
		_expect(display.is_fullscreen(), "Menu enters fullscreen")
		hud.get_node("%DisplayMode").item_selected.emit(0)
		await _settle()
		_expect(not display.is_fullscreen(), "Menu returns to window")
	for size in [Vector2i(960, 600), Vector2i(1280, 720), Vector2i(1280, 960), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160)]:
		session.start_dialogue(&"test_guest_intro")
		window.size = size
		await _settle()
		_expect(window.size == size, "Actual window matches requested resolution " + str(size))
		var bounds: Rect2 = hud.get_node("Screen").get_global_rect()
		_expect(bounds.size.x >= 1278 and bounds.size.y >= 718, "Logical area accommodates baseline at " + str(size))
		session.open_menu()
		await _settle()
		_expect(_fits(hud.get_node("%Resume").get_global_rect(), bounds) and _fits(hud.get_node("%Quit").get_global_rect(), bounds), "Menu actions fit " + str(size))
		_capture("menu_%dx%d" % [size.x, size.y])
		session.resume_menu()
		session.open_journal()
		await _settle()
		_expect(_fits(journal.get_node("%BookArt").get_global_rect(), bounds) and _fits(journal.get_node("%Close").get_global_rect(), bounds), "Book fits " + str(size))
		_capture("book_%dx%d" % [size.x, size.y])
		session.close_journal()
		await _settle()
		_expect(session.mode == NarrativeSession.DIALOGUE and _fits(main.get_node("DialoguePanel/Screen/Card").get_global_rect(), bounds), "Dialogue survives resize and modal returns " + str(size))
		_capture("dialogue_%dx%d" % [size.x, size.y])
		session.cancel_dialogue()
		session.open_service()
		await _settle()
		_expect(_fits(main.get_node("ServicePanel/Screen/Card").get_global_rect(), bounds), "Service fits " + str(size))
		_capture("service_%dx%d" % [size.x, size.y])
		session.close_service()
	_expect(session.shift.remaining == 2 and session.journal.get_entries().size() == 2 and not session.service.served, "Display changes preserve gameplay state")
	JournalPanel.motion_mode = &"full"
	print("%s: display settings, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
