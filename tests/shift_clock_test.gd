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


func _run() -> void:
	JournalPanel.motion_mode = &"off"
	create_timer(20).timeout.connect(func() -> void:
		printerr("FAIL: shift test timed out")
		quit(1)
	)
	_test_clock()
	await _test_scene(false)
	await _test_scene(true)
	await _test_repeat_dialogues_and_restart()
	print("%s: shift clock and bar layout, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_clock() -> void:
	var clock := ShiftClock.new()
	_expect(not clock.apply_completed_event(&"a", 1), "No event before configuration")
	_expect(not clock.configure(0) and not clock.configure(-1), "Non-positive budget rejected")
	_expect(clock.configure(2) and clock.remaining == 2, "Valid initial budget")
	_expect(not clock.configure(3), "Cannot silently reset budget")
	_expect(not clock.apply_completed_event(&"", 1) and not clock.apply_completed_event(&"bad", -1), "Invalid event and cost rejected")
	var finishes: Array[bool] = []
	var reentrant: Array[bool] = []
	var clock_ref: WeakRef = weakref(clock)
	clock.progress_changed.connect(func(_left: int, _total: int) -> void: reentrant.append(clock_ref.get_ref().apply_completed_event(&"nested", 0)))
	clock.shift_finished.connect(func() -> void: finishes.append(clock_ref.get_ref().finished))
	_expect(clock.apply_completed_event(&"zero", 0) and clock.remaining == 2, "Zero-cost event is valid")
	_expect(not clock.apply_completed_event(&"zero", 1), "Duplicate zero event cannot be charged later")
	_expect(clock.apply_completed_event(&"first", 1) and clock.remaining == 1 and not clock.finished, "First event spends one")
	_expect(not clock.apply_completed_event(&"first", 1) and clock.remaining == 1, "Duplicate event is a no-op")
	_expect(clock.apply_completed_event(&"last", 999) and clock.remaining == 0 and clock.finished, "Overshoot clamps to zero")
	_expect(finishes.size() == 1 and finishes[0], "End emitted once after committing state")
	_expect(not reentrant.has(true), "Progress callback cannot add nested event")
	_expect(not clock.apply_completed_event(&"later", 1) and finishes.size() == 1, "No further event after end")
	var events := clock.get_events()
	events[0].time_cost = 100
	events.clear()
	_expect(clock.get_events().size() == 3 and clock.get_events()[0].time_cost == 0, "Event history is copied")


func _new_scene() -> Node:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.free_roam_enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	rig.fade_seconds = 0.02
	rig.black_hold_seconds = 0.02
	return main


func _close_scene(main: Node) -> void:
	current_scene = null
	main.queue_free()
	await process_frame


func _short_dialogue(main: Node) -> void:
	var session := main.get_node("NarrativeSession") as NarrativeSession
	_expect(main.start_test_dialogue(), "Start from bartender anchor")
	_expect(session.choose_for_node(&"test_guest_intro", &"opening", &"leave"), "Choose short branch")
	_expect(session.finish_for_node(&"test_guest_intro", &"goodbye"), "Explicit finish accepted")


func _test_scene(service_first: bool) -> void:
	var main: Node = await _new_scene()
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var session := main.get_node("NarrativeSession") as NarrativeSession
	var guest := main.get_node("DialogueTrigger") as ServiceGuest
	var bar := main.get_node("BarLevel/Geometry/CounterTop") as Node3D
	_expect(not main.restart_shift(), "Cannot restart unfinished shift")
	rig.request_move(&"counter")
	await rig.anchor_reached
	_expect(rig.global_position.x < bar.global_position.x and guest.global_position.x > bar.global_position.x, "Player behind bar and guest in hall")
	_expect((-rig.view.global_basis.z).dot(rig.global_position.direction_to(guest.global_position)) > 0.99, "Camera faces guest")
	_expect(guest.global_basis.x.dot(guest.global_position.direction_to(rig.global_position)) > 0.99, "Guest faces bartender")
	_expect(rig.get_anchor(&"counter").display_name == "За стойкой", "Work anchor clearly named")
	session.open_journal()
	session.close_journal()
	session.open_menu()
	session.resume_menu()
	await create_timer(0.04).timeout
	_expect(session.shift.remaining == 2, "Navigation, idle, journal and menu are free")
	main.start_test_dialogue()
	session.cancel_dialogue()
	main.open_service_menu()
	session.close_service()
	_expect(session.shift.remaining == 2, "Cancelled conversation and service are free")
	var ends: Array[bool] = []
	session.shift.shift_finished.connect(func() -> void: ends.append(true))
	if service_first:
		main.open_service_menu()
		session.serve_drink(&"test_water")
	else:
		_short_dialogue(main)
	_expect(session.shift.remaining == 1 and session.mode == NarrativeSession.EXPLORATION, "First completed action consumes one")
	var first_event: StringName = StringName(session.shift.get_events()[0].id)
	_expect(not session.shift.apply_completed_event(first_event, 1) and session.shift.remaining == 1, "Repeated completion not charged twice")
	if service_first:
		_short_dialogue(main)
	else:
		main.open_service_menu()
		session.serve_drink(&"test_house_drink")
	_expect(session.shift.remaining == 0 and ends.size() == 1, "Two completed actions end shift exactly once")
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE and main.get_node("ShiftSummaryPanel/Screen").visible, "Summary replaces gameplay")
	_expect(not rig.request_move(&"entry") and not main.start_test_dialogue() and not main.open_service_menu(), "Finished shift blocks world and actions")
	_expect(guest.get_node("ServedGlass").visible and session.service.served, "Last service still has visible result")
	_expect(main.get_node("NavigationHUD/%ShiftTime").text.contains("0 / 2"), "HUD agrees with model")
	session.open_journal()
	_expect(session.mode == NarrativeSession.JOURNAL and main.get_node("JournalPanel/%Close").text == "К итогам смены", "Summary journal has correct return")
	session.close_journal()
	session.open_menu()
	session.resume_menu()
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE and session.shift.remaining == 0, "Journal and menu cannot resume ended world")
	await _close_scene(main)


func _test_repeat_dialogues_and_restart() -> void:
	var main: Node = await _new_scene()
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var session := main.get_node("NarrativeSession") as NarrativeSession
	rig.request_move(&"counter")
	await rig.anchor_reached
	_short_dialogue(main)
	_short_dialogue(main)
	var events := session.shift.get_events()
	_expect(events.size() == 2 and events[0].id != events[1].id, "Repeated dialogue has unique run IDs")
	_expect(session.shift.finished and not session.service.served, "Two conversations can exhaust budget without service")
	var old_ref: WeakRef = weakref(main)
	main.get_node("ShiftSummaryPanel/%Restart").pressed.emit()
	await process_frame
	await process_frame
	var fresh: Node = current_scene
	_expect(old_ref.get_ref() == null and fresh != null, "Restart reloads actual game scene")
	if fresh != null:
		var new_session := fresh.get_node("NarrativeSession") as NarrativeSession
		_expect(new_session.shift.remaining == 2 and not new_session.shift.finished and not new_session.service.served and new_session.journal.get_entries().is_empty(), "New shift resets clock, order and journal")
		_expect(fresh.get_node("AnchorCamera").current_anchor_id == &"entry", "New shift starts at entry")
		await _close_scene(fresh)
