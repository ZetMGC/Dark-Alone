extends Node
## Новый игровой путь: физическая ходьба, локальные рабочие места, смена и файл.

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


func _release() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)


func _walk(rig: FreeRoamCamera, destination: Vector3) -> void:
	for frame in 360:
		var offset := destination - rig.body.global_position
		offset.y = 0
		if offset.length() < 0.09:
			break
		var forward := -rig.view.global_basis.z
		var yaw := atan2(-forward.x, -forward.z)
		var local := Basis(Vector3.UP, yaw).inverse() * offset.normalized()
		Input.action_press("move_right", maxf(local.x, 0))
		Input.action_press("move_left", maxf(-local.x, 0))
		Input.action_press("move_back", maxf(local.z, 0))
		Input.action_press("move_forward", maxf(-local.z, 0))
		await get_tree().physics_frame
		await get_tree().process_frame
	_release()
	var distance := rig.body.global_position - destination
	distance.y = 0
	_expect(distance.length() < 0.15, "Walk route reaches " + str(destination))


func _still(rig: FreeRoamCamera, label: String) -> void:
	var position := rig.body.global_position
	Input.action_press("move_forward")
	for frame in 4:
		await get_tree().physics_frame
		await get_tree().process_frame
	_release()
	_expect(rig.body.global_position.is_equal_approx(position), "Movement blocked: " + label)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame


func _focus(rig: FreeRoamCamera, id: StringName) -> void:
	_expect(rig.request_move(id), "Nearby workstation accepted: " + str(id))
	while rig.is_transitioning:
		await get_tree().process_frame
	_expect(rig.focus_active and rig.current_anchor_id == id, "Focused: " + str(id))


func _snap(label: String) -> void:
	if _capture.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_expect(get_viewport().get_texture().get_image().save_png(_capture.path_join(label + ".png")) == OK, "Capture " + label)


func _run() -> void:
	get_tree().create_timer(40).timeout.connect(func() -> void:
		printerr("FAIL: free roam timed out")
		get_tree().quit(1)
	)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(_capture)
	if "--small" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(960, 600)
	JournalPanel.motion_mode = &"off"
	var store := CheckpointStore.new("user://checkpoint_tests/roam_" + str(Time.get_ticks_usec()))
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_store = store
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var hud: NavigationHUD = main.get_node("NavigationHUD")
	var home: HomeExploration = main.get_node("HomeExploration")
	rig.fade_seconds = 0.01
	rig.black_hold_seconds = 0
	await get_tree().physics_frame
	await get_tree().process_frame
	_expect(main.free_roam_enabled and rig.body != null and rig.current_anchor_id == &"", "Default game boots into free walk")
	_expect(not hud.get_node("Screen/Bottom").visible and not hud.get_node("Screen/Actions").visible, "Walking has no destination/action rows")
	_expect(not rig.request_move(&"counter") and not rig.request_move(&"missing"), "Far and unknown workstations rejected")
	_expect(not main.start_test_dialogue() and not main.open_service_menu(), "Remote talk/service rejected")
	var spawn := rig.body.global_position
	await _key(KEY_2)
	_expect(rig.body.global_position.is_equal_approx(spawn), "Old number shortcut does not teleport")
	rig._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _still(rig, "lost application focus")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Focus loss releases mouse")
	rig._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _snap("01-bar-walk")
	# Реальный маршрут вокруг конца стойки, без перестановки тела.
	await _walk(rig, Vector3(-4.9, 0, 2.3))
	await _walk(rig, Vector3(-4.9, 0, -0.5))
	_expect(rig.body.is_on_floor() and absf(rig.view.global_position.y - 1.65) < 0.03, "Body stays grounded at human eye height")
	# Преграда в пределах радиуса: близость сама по себе не даёт пройти сквозь стену.
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 2.2, 0.1)
	shape.shape = box
	blocker.add_child(shape)
	main.add_child(blocker)
	blocker.global_position = Vector3(-4.9, 1.1, -0.85)
	await get_tree().physics_frame
	_expect(not rig.request_move(&"counter"), "Nearby workstation blocked by wall")
	blocker.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var approach := rig.body.global_position
	await _key(KEY_E)
	while rig.is_transitioning:
		await get_tree().process_frame
	_expect(rig.focus_active and rig.current_anchor_id == &"counter", "E enters counter from nearby facing approach")
	_expect(hud.get_node("Screen/Actions").visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Workstation shows cursor and actions")
	await _still(rig, "workstation")
	var basis := rig.view.global_basis
	rig.apply_look_delta(Vector2(1, 1))
	_expect(rig.view.global_basis.is_equal_approx(basis), "Workstation camera fixed")
	await _snap("02-counter")
	await _key(KEY_J)
	await _still(rig, "journal")
	session.close_journal()
	session.open_menu()
	await _still(rig, "menu")
	_expect(not rig.leave_focus(), "Cannot leave through modal menu")
	session.resume_menu()
	await _key(KEY_ESCAPE)
	_expect(not rig.focus_active and session.mode == NarrativeSession.EXPLORATION and rig.body.global_position.is_equal_approx(approach), "Escape returns to exact approach without opening menu")
	if DisplayServer.get_name() != "headless":
		_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Walking recaptures mouse")
	Input.action_press("move_right")
	for frame in 24:
		await get_tree().physics_frame
		await get_tree().process_frame
	_release()
	_expect(rig.body.global_position.x > approach.x + 0.1 and rig.body.global_position.x < -4.5, "Physical walking stops against counter")
	_expect(rig.body.test_move(rig.body.global_transform, Vector3(-3, 0, 0)), "Outer wall blocks capsule")
	var table_pose := Transform3D(Basis.IDENTITY, Vector3(2.1, 0.01, -2.8))
	_expect(rig.body.test_move(table_pose, Vector3(2, 0, 0)), "Table collision blocks capsule")
	var guest_pose := Transform3D(Basis.IDENTITY, Vector3(-1.7, 0.01, -1.2))
	_expect(rig.body.test_move(guest_pose, Vector3(-1, 0, 0)), "Guest blocks physical walking")
	await _walk(rig, approach)
	await _focus(rig, &"counter")
	_expect(main.start_test_dialogue(), "Talk accessible at workstation")
	await _still(rig, "dialogue")
	_expect(not rig.leave_focus(), "Dialogue locks workstation exit")
	session.choose_for_node(&"test_guest_intro", &"opening", &"leave")
	session.finish_for_node(&"test_guest_intro", &"goodbye")
	_expect(main.open_service_menu(), "Service accessible after dialogue")
	await _still(rig, "service")
	session.serve_drink(&"test_water")
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE and session.shift.remaining == 0, "Actions still complete two-division shift")
	await _still(rig, "summary")
	session.go_home()
	await _still(rig, "travel")
	session.finish_commute(session.commute.trip_id)
	var home_rig := home.rig as FreeRoamCamera
	home_rig.fade_seconds = 0.01
	home_rig.black_hold_seconds = 0
	_expect(session.mode == NarrativeSession.HOME and home_rig.free_roam_enabled and home_rig.current_anchor_id == &"", "Home uses the same free walk")
	_expect(not home.get_node("HomeHUD/Screen/Bottom").visible, "Home navigation row hidden while walking")
	_expect(not home.open_event(), "Home event unavailable without workstation")
	await _still(rig, "inactive bar while at home")
	await _walk(home_rig, home.to_global(Vector3(-2.2, 0, -0.4)))
	await _focus(home_rig, &"home_desk")
	_expect(home.inspect(&"home_desk"), "Home inspection at desk")
	await _still(home_rig, "inspection")
	_expect(home.close_inspection(true) and home.state.has_observed(&"home_desk"), "Inspection commits observation")
	await _snap("03-home-workstation")
	home_rig.leave_focus()
	await _walk(home_rig, home.to_global(Vector3(1.4, 0, -1.4)))
	await _focus(home_rig, &"home_window")
	home.inspect(&"home_window")
	home.close_inspection(true)
	_expect(home.open_event() and home.close_inspection(true), "Independent event still resolves")
	home_rig.leave_focus()
	await _walk(home_rig, home.to_global(Vector3(0.35, 0, -1.4)))
	await _walk(home_rig, home.to_global(Vector3(0.35, 0, 1.5)))
	await _focus(home_rig, &"home_bed")
	_expect(absf(home_rig.view.global_basis.x.dot(Vector3.UP)) < 0.001, "Focused home camera has level horizon")
	_expect(not home.request_work(), "Cannot leave for work at bed")
	home_rig.leave_focus()
	await _walk(home_rig, home.to_global(Vector3(-1.8, 0, 1.9)))
	await _focus(home_rig, &"home_entry")
	_expect(home.request_work(), "Door starts route to work")
	session.finish_commute(session.commute.trip_id)
	await get_tree().process_frame
	await get_tree().process_frame
	main = get_tree().current_scene
	rig = main.get_node("AnchorCamera")
	session = main.get_node("NarrativeSession")
	_expect(main.free_roam_enabled and not rig.focus_active and rig.current_anchor_id == &"" and session.shift_number == 2, "Next shift reloads free walk")
	var catalog := DialogueCatalog.new()
	catalog.load_files("res://content/glossary/test_terms.json", PackedStringArray(["res://content/dialogues/test_guest.json"]))
	var saved := store.load_checkpoint(catalog)
	_expect(not saved.is_empty() and saved.shift == 2 and saved.home_state.has_resolved(&"test_home_observation"), "New movement preserves boundary autosave")
	get_tree().current_scene = null
	main.queue_free()
	await get_tree().process_frame
	main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_store = CheckpointStore.new(store.get_path().get_base_dir())
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	rig = main.get_node("AnchorCamera")
	session = main.get_node("NarrativeSession")
	_expect(main.free_roam_enabled and session.shift_number == 2 and rig.current_anchor_id == &"" and not rig.focus_active, "Disk load resumes free walk at shift start")
	_expect(main.get_node("HomeExploration").state.has_resolved(&"test_home_observation") and not session.journal.get_known_term_ids().is_empty(), "Disk load preserves home and journal with new controller")
	_expect(store.clear_checkpoint(), "Test checkpoint cleaned")
	_release()
	JournalPanel.motion_mode = &"full"
	print("%s: free roam, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
