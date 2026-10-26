extends SceneTree
## Заказ, одноразовая подача, модальные блокировки и наблюдаемый результат.

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _options() -> Array[Dictionary]:
	return [
		{"id": "test_water", "title": "[TEST] Вода", "description": "Стакан воды."},
		{"id": "test_house_drink", "title": "[TEST] Напиток бара", "description": "Напиток в стакане."}
	]


func _run() -> void:
	JournalPanel.motion_mode = &"off"
	create_timer(20).timeout.connect(func() -> void:
		printerr("FAIL: service test timed out")
		quit(1)
	)
	_test_model()
	await _test_scene()
	await process_frame
	print("%s: guest service, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_model() -> void:
	var unconfigured := GuestService.new()
	_expect(not unconfigured.serve(&"test_water") and not unconfigured.served, "No service before configuration")
	_expect(not unconfigured.configure(&"Bad Id", _options()) and not unconfigured.is_configured(), "Bad guest ID rejected atomically")
	_expect(unconfigured.configure(&"test_guest", _options()), "Valid retry after configuration error")
	for invalid_kind: String in ["empty", "duplicate", "missing", "bad_id", "unknown_field", "blank"]:
		var menu := _options()
		match invalid_kind:
			"empty": menu.clear()
			"duplicate": menu[1].id = menu[0].id
			"missing": menu[0].erase("description")
			"bad_id": menu[0].id = "BAD ID"
			"unknown_field": menu[0]["price"] = 10
			"blank": menu[0].title = "  "
		var service := GuestService.new()
		_expect(not service.configure(&"test_guest", menu), "Reject invalid menu: " + invalid_kind)
		_expect(not service.is_configured() and service.get_options().is_empty() and not service.validation_errors.is_empty(), "Invalid menu exposes no partial options")
	for id: StringName in [&"test_water", &"test_house_drink"]:
		var service := GuestService.new()
		var source := _options()
		_expect(service.configure(&"test_guest", source), "Menu accepted")
		source[0].title = "MUTATED"
		var options := service.get_options()
		options[0].title = "MUTATED"
		_expect(service.get_options()[0].title != "MUTATED", "Menu source and getter do not mutate model")
		var events: Array = []
		var service_ref: WeakRef = weakref(service)
		var reentrant: Array[bool] = []
		service.service_completed.connect(func(event: StringName, guest: StringName, drink: StringName) -> void:
			events.append([event, guest, drink])
			reentrant.append(service_ref.get_ref().serve(drink))
		)
		_expect(not service.serve(&"missing") and not service.served, "Unknown drink does not complete order")
		_expect(service.serve(id) and service.served and service.selected_drink_id == id, "Chosen drink completes service")
		_expect(events.size() == 1 and events[0] == [&"service:test_guest", &"test_guest", id], "Stable completion ID and payload")
		_expect(not service.serve(id) and not reentrant.has(true) and events.size() == 1, "Repeated and reentrant service rejected")
		_expect(not service.configure(&"other", _options()) and service.served, "Configuration cannot erase served state")
		var served := service.get_served_drink()
		served.title = "MUTATED"
		_expect(service.get_served_drink().title != "MUTATED", "Served snapshot is a copy")


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.physical_keycode = key
	release.keycode = key
	Input.parse_input_event(release)


func _buttons(panel: ServicePanel) -> Array[Button]:
	var result: Array[Button] = []
	for child in panel.get_node("%Options").get_children():
		if child is Button:
			result.append(child)
	return result


func _test_scene() -> void:
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := scene.instantiate()
	main.checkpoint_enabled = false
	root.add_child(main)
	await process_frame
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var session := main.get_node("NarrativeSession") as NarrativeSession
	var panel := main.get_node("ServicePanel") as ServicePanel
	var guest := main.get_node("DialogueTrigger") as ServiceGuest
	var hud := main.get_node("NavigationHUD") as NavigationHUD
	rig.fade_seconds = 0.02
	rig.black_hold_seconds = 0.02
	_expect(guest is Interactable3D and not guest.get_node("ServedGlass").visible, "Guest uses common interaction and starts without served glass")
	_expect(not main.open_service_menu(), "Cannot serve away from counter")
	rig.request_move(&"counter")
	_key(KEY_B)
	_expect(session.mode == NarrativeSession.EXPLORATION, "Service cannot open during fade")
	await rig.anchor_reached
	_key(KEY_B)
	await process_frame
	_expect(session.mode == NarrativeSession.SERVICE and panel.screen.visible and _buttons(panel).size() == 2, "B opens short menu at counter")
	_expect(not rig.request_move(&"table") and not main.start_test_dialogue() and not session.open_journal(), "Service locks world, dialogue and journal")
	var look_before := rig.view.rotation
	rig.apply_look_delta(Vector2.ONE)
	_expect(rig.view.rotation == look_before, "Service blocks camera look")
	_key(KEY_ESCAPE)
	await process_frame
	_expect(session.mode == NarrativeSession.EXPLORATION and not session.service.served and not guest.get_node("ServedGlass").visible, "Escape cancels menu without serving")
	hud.service_requested.emit()
	await process_frame
	panel.get_node("%Menu").pressed.emit()
	await process_frame
	_expect(session.mode == NarrativeSession.MENU and not panel.screen.visible, "Pause menu overlays service")
	_expect(not session.serve_drink(&"test_water"), "Hidden service command rejected")
	_key(KEY_ESCAPE)
	await process_frame
	_expect(session.mode == NarrativeSession.SERVICE and panel.screen.visible, "Pause resumes service menu")
	_expect(not session.serve_drink(&"missing") and not session.service.served, "Unknown menu ID is a no-op")
	var events: Array = []
	session.service_completed.connect(func(id: StringName, guest_id: StringName, drink_id: StringName) -> void: events.append([id, guest_id, drink_id]))
	var button := _buttons(panel)[0]
	var stale_command: Callable = button.pressed.get_connections()[0].callable
	_key(KEY_TAB)
	await process_frame
	_expect(root.gui_get_focus_owner() == button, "Tab focuses first drink")
	_key(KEY_ENTER)
	await process_frame
	_expect(session.service.served and session.service.selected_drink_id == &"test_water", "Rendered option serves selected drink")
	_expect(session.mode == NarrativeSession.EXPLORATION and not panel.screen.visible, "Serving returns to exploration")
	_expect(guest.get_node("ServedGlass").visible and hud.get_node("%ServiceStatus").text.contains("Вода"), "World glass and status show result")
	_expect(events.size() == 1 and events[0][0] == &"service:test_guest", "Scene emits completion once")
	stale_command.call()
	_expect(not main.open_service_menu() and events.size() == 1 and hud.get_node("%Service").disabled, "Served guest rejects repeated and stale actions")
	_expect(session.journal.get_entries().is_empty(), "Service does not silently grant dialogue terms")
	await physics_frame
	await physics_frame
	await process_frame
	_key(KEY_E)
	await process_frame
	_expect(session.mode == NarrativeSession.DIALOGUE, "Same guest still supports dialogue after service")
	_expect(not main.open_service_menu(), "Dialogue blocks service shortcut")
	session.cancel_dialogue()
	_expect(rig.can_move_to(&"entry"), "Navigation restored after conversation")
	rig.request_move(&"entry")
	await rig.anchor_reached
	rig.request_move(&"counter")
	await rig.anchor_reached
	_expect(session.service.served and guest.get_node("ServedGlass").visible, "Leaving and returning preserves served state")
	main.queue_free()
	await process_frame
	var fresh := scene.instantiate()
	fresh.checkpoint_enabled = false
	root.add_child(fresh)
	await process_frame
	_expect(not fresh.get_node("NarrativeSession").service.served and not fresh.get_node("DialogueTrigger/ServedGlass").visible, "Fresh session resets order")
	fresh.queue_free()
	await process_frame
