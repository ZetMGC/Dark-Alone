extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _save(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var suffix := "_small" if "--small" in OS.get_cmdline_user_args() else ""
	_expect(root.get_texture().get_image().save_png("res://artifacts/da049_" + name + suffix + ".png") == OK, "Screenshot " + name)


func _run() -> void:
	create_timer(30).timeout.connect(func() -> void:
		printerr("FAIL: home test timeout")
		quit(1)
	)
	JournalPanel.motion_mode = &"off"
	if "--small" in OS.get_cmdline_user_args():
		root.size = Vector2i(960, 600)
	var state := HomeState.new()
	_expect(not state.observe(&"unknown") and not state.resolve_event(&"test_home_observation"), "Unknown observation and premature event rejected")
	_expect(state.observe(&"home_desk") and not state.observe(&"home_desk"), "Observation is one-time")
	_expect(state.get_available_events().is_empty(), "All event prerequisites required")
	_expect(state.observe(&"home_window"), "Second observation accepted")
	var copy := state.get_available_events()
	copy[0].requires.clear()
	_expect(state.get_available_events()[0].requires.size() == 2, "Event getter does not mutate definitions")
	_expect(state.resolve_event(&"test_home_observation") and not state.resolve_event(&"test_home_observation"), "Event resolves once")
	var nested_state := HomeState.new()
	var nested: Array[bool] = []
	var state_ref: WeakRef = weakref(nested_state)
	nested_state.changed.connect(func() -> void: nested.append(state_ref.get_ref().observe(&"home_bed")))
	nested_state.observe(&"home_desk")
	_expect(nested == [false] and not nested_state.has_observed(&"home_bed"), "Signal callbacks cannot reenter progress mutations")
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	main.free_roam_enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var bar: AnchorCamera = main.get_node("AnchorCamera")
	var home: HomeExploration = main.get_node("HomeExploration")
	_expect(not home.visible and not home.inspect(&"home_desk") and not home.request_work(), "Home unavailable during work")
	bar.fade_seconds = 0.02
	bar.black_hold_seconds = 0.0
	bar.request_move(&"counter")
	await bar.anchor_reached
	for repeat in 2:
		main.start_test_dialogue()
		session.choose_for_node(&"test_guest_intro", &"opening", &"leave")
		session.finish_for_node(&"test_guest_intro", &"goodbye")
	_expect(session.go_home(), "Completed shift can depart")
	session.finish_commute(session.commute.trip_id)
	_expect(session.mode == NarrativeSession.HOME and home.visible and home.rig.view.current, "Arrival selects real home camera")
	_expect(not main.get_node("CommutePanel/Screen").visible and not main.get_node("NavigationHUD/Screen/Bottom").visible, "Old home backdrop and bar HUD hidden")
	main.get_node("CommutePanel/%Work").pressed.emit()
	_expect(session.mode == NarrativeSession.HOME, "Hidden old home controls cannot start a trip")
	var sphere := SphereShape3D.new()
	sphere.radius = 0.15
	for anchor in home.rig.get_anchors():
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = anchor.global_transform
		query.collision_mask = 1
		_expect(home.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "Safe home camera pose: " + str(anchor.anchor_id))
	var baseline := [session.shift.remaining, session.journal.get_entries().size(), session.service.served]
	var home_state := home.state
	home.rig.fade_seconds = 0.04
	home.rig.black_hold_seconds = 0.02
	await _save("entry")
	_expect(not home.inspect(&"home_desk"), "Cannot inspect remote object")
	var destination_key := InputEventKey.new()
	destination_key.physical_keycode = KEY_2
	destination_key.keycode = KEY_2
	destination_key.pressed = true
	root.push_input(destination_key)
	_expect(not home.request_work() and not home.inspect(&"home_desk"), "No exit or inspection during transition")
	await home.rig.anchor_reached
	_expect(home.inspect(&"home_desk"), "Inspect available desk")
	_expect(not home.rig.can_move_to(&"home_entry") and not home.open_event(), "Inspection locks movement and nested events")
	await _save("inspection")
	home.close_inspection(false)
	_expect(not home.state.has_observed(&"home_desk"), "Cancelled inspection does not mark observation")
	home.inspect(&"home_desk")
	session.open_journal(true)
	_expect(not home.close_inspection(true) and session.mode == NarrativeSession.JOURNAL, "Hidden inspection cannot commit behind journal")
	await _save("journal")
	session.close_journal()
	_expect(home.get_node("%Inspection").visible, "Journal returns to pending inspection")
	home.close_inspection(true)
	_expect(home.state.has_observed(&"home_desk"), "Completed inspection marks state")
	home.inspect(&"home_desk")
	home.close_inspection(true)
	_expect(home.state.get_observed_ids().size() == 1, "Repeated reading does not duplicate observation")
	session.open_menu()
	_expect(not home.rig.request_move(&"home_window") and not home.inspect(&"home_desk"), "Pause blocks home input")
	await _save("menu")
	session.resume_menu()
	home.rig.fade_seconds = 0.04
	home.rig.black_hold_seconds = 0.02
	await _save("desk")
	home.rig.request_move(&"home_window")
	await home.rig.anchor_reached
	await physics_frame
	await physics_frame
	_expect(home.interaction.try_interact(), "Ray sees window from matching anchor")
	home.close_inspection(true)
	_expect(home.state.get_available_events().size() == 1 and home.get_node("%Event").visible, "Observations unlock independent event")
	await _save("window")
	_expect(home.open_event(), "Event can open after requirements")
	await _save("event")
	home.close_inspection(false)
	_expect(not home.state.has_resolved(&"test_home_observation"), "Cancelled event stays available")
	home.open_event()
	home.close_inspection(true)
	_expect(home.state.has_resolved(&"test_home_observation") and not home.open_event(), "Completed event cannot repeat")
	home.rig.request_move(&"home_bed")
	await home.rig.anchor_reached
	await _save("bed")
	home.rig.apply_look_delta(Vector2(0.8, -0.1))
	_expect(absf(home.rig.view.global_basis.x.y) < 0.00001, "Home bed stays level while turning")
	await _save("bed_look")
	home.rig.reset_look()
	_expect(home.inspect(&"home_bed"), "Bed inspection available")
	home.close_inspection(true)
	_expect(not home.request_work(), "Leaving for work requires door anchor")
	home.rig.request_move(&"home_entry")
	await home.rig.anchor_reached
	for id: StringName in [&"home_bed", &"home_window", &"home_desk", &"home_entry"]:
		var accepted := home.rig.request_move(id)
		_expect(accepted, "Reverse home route: " + str(id))
		if accepted:
			await home.rig.anchor_reached
	_expect(baseline == [session.shift.remaining, session.journal.get_entries().size(), session.service.served], "Home exploration does not spend bar time or grant terms")
	_expect(home.request_work(), "Door starts return trip")
	_expect(not home.request_work() and not home.visible, "Double exit rejected, home hidden during trip")
	session.finish_commute(session.commute.trip_id)
	await process_frame
	await process_frame
	var next: Node = current_scene
	_expect(next.get_node("HomeExploration").state == home_state and home_state.has_resolved(&"test_home_observation"), "Home observations/events survive actual next-shift reload")
	_expect(next.get_node("NarrativeSession").shift_number == 2 and next.get_node("AnchorCamera").view.current, "Return creates next shift with bar camera")
	next.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("%s: explorable home, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
