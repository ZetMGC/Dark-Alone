extends Node
## Реальные лучи дома; пользовательские настройки/сохранения отключены.

var _checks: int = 0
var _failures: int = 0
var _capture: String = ""
var home: HomeExploration
var rig: FreeRoamCamera


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _aim(point: Vector3) -> void:
	rig.reset_look()
	var current := -rig.view.global_basis.z.normalized()
	var direction := (point - rig.view.global_position).normalized()
	rig.apply_look_delta(Vector2(atan2(-direction.x, -direction.z) - atan2(-current.x, -current.z), asin(direction.y) - asin(current.y)))


func _place(feet: Vector3, point: Vector3) -> void:
	rig.body.global_position = home.to_global(feet)
	rig.body.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().process_frame
	_aim(home.to_global(point))
	await get_tree().physics_frame
	await get_tree().process_frame


func _point(point: Vector3) -> void:
	var screen := rig.view.unproject_position(home.to_global(point))
	get_viewport().warp_mouse(screen)
	var event := InputEventMouseMotion.new()
	event.position = screen
	event.global_position = screen
	get_viewport().push_input(event, true)
	await get_tree().process_frame


func _snap(name: String) -> void:
	if _capture.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_expect(get_viewport().get_texture().get_image().save_png(_capture.path_join(name + ".png")) == OK, "Capture " + name)


func _run() -> void:
	get_tree().create_timer(35).timeout.connect(func() -> void:
		printerr("FAIL: home targeting timeout")
		get_tree().quit(1)
	)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(_capture)
	if "--small" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(960, 600)
	JournalPanel.motion_mode = &"off"
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var session: NarrativeSession = main.get_node("NarrativeSession")
	home = main.get_node("HomeExploration")
	rig = home.rig
	_expect(not home.interaction.try_interact(), "Home inactive during work")
	# Два завершения через публичный Session: изолируем проверку дома от бара.
	for repeat in 2:
		_expect(session.start_dialogue(&"test_guest_intro"), "Start fixture conversation")
		session.choose_for_node(&"test_guest_intro", &"opening", &"leave")
		session.finish_for_node(&"test_guest_intro", &"goodbye")
	_expect(session.go_home(), "Shift permits trip home")
	session.finish_commute(session.commute.trip_id)
	rig.fade_seconds = 0.1
	rig.black_hold_seconds = 0
	await get_tree().physics_frame
	_expect(session.mode == NarrativeSession.HOME and rig.free_roam_enabled, "Current real home walking mode")
	for anchor in rig.get_anchors():
		_expect(not anchor.get_node("Marker").visible and anchor.collision_layer == 0, "No marker collider: " + str(anchor.anchor_id))
	for object: HomeObject in home.get_node("Objects").get_children():
		_expect(object.collision_layer == 0, "Legacy sphere disabled: " + str(object.object_id))
	var points := [
		["Desk", &"home_desk", &"home_desk", Vector3(-2.2, 0, -0.55), Vector3(-2.2, 0.92, -1.9)],
		["Window", &"home_window", &"home_window", Vector3(1.6, 0, -1.4), Vector3(3.43, 1.9, -1.7)],
		["Bed", &"home_bed", &"home_bed", Vector3(0.5, 0, 1.5), Vector3(2.15, 0.69, 1.4)],
		["Door", &"home_entry", &"home_door", Vector3(-1.8, 0, 1.9), Vector3(-1.8, 1.4, 2.87)],
	]
	var baseline := [session.shift.remaining, session.journal.get_entries().size()]
	for item: Array in points:
		await _place(item[3], item[4])
		var approach := rig.body.global_position
		var forward := -rig.view.global_basis.z
		var target: Interactable3D = home.get_node(item[0] + "SurfaceTarget")
		_expect(home.interaction.get_target() == target and target.is_available(), "Visible surface selected: " + item[0])
		_expect(not rig.focus_active, "Hover does not activate: " + item[0])
		await _snap(item[0] + "-approach")
		await _key(KEY_E)
		_expect(rig.focus_active and rig.is_transitioning and not home.interaction.try_interact(), "E enters once and fade blocks interaction: " + item[0])
		while rig.is_transitioning:
			await get_tree().process_frame
		_expect(rig.current_anchor_id == item[1] and home.interaction.pointer_mode, "Correct workstation and pointer: " + item[0])
		await _point(item[4])
		_expect(home.interaction.get_target() == target, "Pointer hits real surface: " + item[0])
		await _snap(item[0] + "-cursor")
		await _key(KEY_E)
		_expect(home.get_node("HomeHUD/Screen/Inspection").visible and not home.interaction.try_interact(), "Pointer E opens inspection and blocks world: " + item[0])
		var still := rig.body.global_position
		Input.action_press("move_forward")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("move_forward")
		_expect(rig.body.global_position.is_equal_approx(still), "Inspection blocks physical movement")
		await _key(KEY_J)
		_expect(session.mode == NarrativeSession.JOURNAL and not home.interaction.try_interact(), "Journal from inspection blocks world")
		session.request_close_journal()
		await get_tree().process_frame
		_expect(session.mode == NarrativeSession.HOME and home.get_node("HomeHUD/Screen/Inspection").visible, "Journal preserves unfinished inspection")
		await _snap(item[0] + "-inspection")
		await _key(KEY_ESCAPE)
		_expect(not home.state.has_observed(item[2]) and rig.focus_active, "Cancel is free and preserves focus: " + item[0])
		_expect(home.inspect(item[2]) and home.close_inspection(true), "Inspection commits: " + item[0])
		_expect(home.inspect(item[2]) and home.close_inspection(true) and home.state.get_observed_ids().count(item[2]) == 1, "Observation stays unique: " + item[0])
		if item[0] != "Door":
			_expect(not home.request_work(), "Exit denied away from door")
		session.open_menu()
		_expect(not home.interaction.try_interact(), "Menu blocks home")
		session.resume_menu()
		_expect(rig.focus_active and rig.current_anchor_id == item[1], "Menu preserves workstation")
		await _key(KEY_J)
		_expect(session.mode == NarrativeSession.JOURNAL and not home.interaction.try_interact(), "Journal blocks home")
		session.request_close_journal()
		await get_tree().process_frame
		_expect(session.mode == NarrativeSession.HOME and rig.focus_active, "Journal returns home focus")
		await _key(KEY_ESCAPE)
		_expect(not rig.focus_active and rig.body.global_position.distance_to(approach) < 0.01 and (-rig.view.global_basis.z).is_equal_approx(forward), "Escape returns approach and look: " + item[0])
	# Старый луч нельзя использовать после отворота; соседняя точка не запасная цель.
	await _place(Vector3(-2.2, 0, -0.55), Vector3(-2.2, 0.92, -1.9))
	_expect(home.interaction.get_target() == home.get_node("DeskSurfaceTarget"), "Prime desk ray")
	_aim(rig.view.global_position + Vector3.UP * 2 + Vector3.RIGHT)
	await _key(KEY_E)
	_expect(not rig.focus_active, "Fresh ray and no nearest-anchor fallback")
	await _place(Vector3(-2.2, 0, 1.3), Vector3(-2.2, 0.92, -1.9))
	await _key(KEY_E)
	_expect(not rig.focus_active, "Distant E cannot teleport")
	# Несвязанный физический блок перехватывает луч перед настоящим предметом.
	await _place(Vector3(-2.2, 0, -0.55), Vector3(-2.2, 0.92, -1.9))
	var obstacle := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 2, 0.1)
	shape.shape = box
	obstacle.add_child(shape)
	home.add_child(obstacle)
	obstacle.position = Vector3(-2.2, 1, -1.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(home.interaction.get_target() == null and not home.interaction.try_interact(), "Nearest unregistered wall blocks surface")
	obstacle.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Выбранная поверхность не работает при чужой текущей камере.
	main.get_node("AnchorCamera/View").make_current()
	await _key(KEY_E)
	_expect(not rig.focus_active, "Inactive home camera cannot activate")
	rig.view.make_current()
	home.set_context(NarrativeSession.HOME)
	await _key(KEY_E)
	while rig.is_transitioning:
		await get_tree().process_frame
	_expect(home.open_event() and home.close_inspection(true) and not home.open_event(), "Original desk/window event resolves once")
	_expect([session.shift.remaining, session.journal.get_entries().size()] == baseline, "Home does not spend time or grant terms")
	rig.leave_focus()
	await _place(Vector3(-1.8, 0, 1.9), Vector3(-1.8, 1.4, 2.87))
	await _key(KEY_E)
	while rig.is_transitioning:
		await get_tree().process_frame
	_expect(home.request_work() and session.mode == NarrativeSession.TRAVEL, "Door keeps work route")
	_expect(not home.interaction.try_interact(), "Trip blocks home")
	session.finish_commute(session.commute.trip_id)
	await get_tree().process_frame
	await get_tree().process_frame
	var next := get_tree().current_scene
	_expect(next != main and next.get_node("NarrativeSession").shift_number == 2 and next.get_node("HomeExploration").state.has_resolved(&"test_home_observation"), "Next shift preserves home progress")
	get_tree().current_scene = null
	next.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	JournalPanel.motion_mode = &"full"
	print("%s: home targets, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
