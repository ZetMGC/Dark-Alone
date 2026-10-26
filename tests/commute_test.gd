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
	create_timer(20).timeout.connect(func() -> void:
		printerr("FAIL: commute test timed out")
		quit(1)
	)
	_test_model()
	await _test_main()
	print("%s: commute, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_model() -> void:
	var flow := CommuteFlow.new()
	_expect(flow.state == CommuteFlow.AT_WORK and flow.trip_id == 0, "Flow starts at work")
	_expect(not flow.start_work() and not flow.complete(0), "No return or completion before departure")
	var states: Array[StringName] = []
	var nested: Array[bool] = []
	var flow_ref: WeakRef = weakref(flow)
	flow.state_changed.connect(func(state: StringName) -> void:
		states.append(state)
		nested.append(flow_ref.get_ref().complete(flow_ref.get_ref().trip_id))
	)
	_expect(flow.start_home() and flow.trip_id == 1, "Home trip has a new ID")
	_expect(not flow.start_home() and not flow.start_work(), "Repeated trip start rejected")
	_expect(not flow.complete(99) and flow.state == CommuteFlow.TO_HOME, "Wrong completion ignored")
	_expect(flow.complete(1) and flow.state == CommuteFlow.AT_HOME, "Arrive at home")
	_expect(not flow.complete(1) and not flow.start_home(), "Duplicate arrival does not depart again")
	_expect(flow.start_work() and flow.trip_id == 2, "Return has another ID")
	_expect(not flow.complete(1), "Stale home callback cannot complete return")
	_expect(flow.complete(2) and flow.state == CommuteFlow.READY, "Ready for new shift once")
	_expect(not flow.complete(2) and not flow.start_home() and not flow.start_work(), "Finished flow cannot reset itself")
	_expect(not nested.has(true) and states.size() == 4, "Callbacks cannot reenter flow")


func _test_main() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var session := main.get_node("NarrativeSession") as NarrativeSession
	var panel := main.get_node("CommutePanel") as CommutePanel
	var presentation := main.get_node("Presentation") as PresentationController
	presentation.set_retro_enabled(false)
	presentation.set_ambience_gain(0)
	_expect(not session.go_home() and not session.go_to_work(), "Cannot leave unfinished shift or skip home")
	rig.fade_seconds = 0.02
	rig.black_hold_seconds = 0.0
	rig.request_move(&"counter")
	await rig.anchor_reached
	for repeat in 2:
		main.start_test_dialogue()
		session.choose_for_node(&"test_guest_intro", &"opening", &"leave")
		session.finish_for_node(&"test_guest_intro", &"goodbye")
	_expect(session.shift.finished and session.journal.get_entries().size() == 1, "Completed shift has journal before departure")
	panel.travel_seconds = 0.5
	main.get_node("ShiftSummaryPanel/%GoHome").pressed.emit()
	var home_id := session.commute.trip_id
	_expect(session.mode == NarrativeSession.TRAVEL and panel.get_node("Screen").visible, "Summary button begins home trip")
	_expect(not session.go_home() and not main.restart_shift(), "Double departure and reset during travel rejected")
	_expect(not session.open_journal() and not main.start_test_dialogue() and not main.open_service_menu(), "Travel blocks journal and game actions")
	_expect(not rig.request_move(&"entry"), "Travel blocks camera")
	await process_frame
	session.open_menu()
	var paused_progress := panel.progress
	await create_timer(0.08).timeout
	_expect(is_equal_approx(panel.progress, paused_progress) and not panel.get_node("Screen").visible, "Menu pauses and hides animated travel")
	_expect(not session.finish_commute(home_id), "Stale completion cannot run under menu")
	session.resume_menu()
	panel.get_node("%Skip").pressed.emit()
	panel.get_node("%Skip").pressed.emit()
	_expect(session.mode == NarrativeSession.HOME and session.commute.state == CommuteFlow.AT_HOME, "Skip arrives home once")
	_expect(session.shift.remaining == 0 and session.journal.get_entries().size() == 1, "Home retains completed shift and journal")
	_expect(not session.finish_commute(home_id) and not session.go_home(), "Home rejects repeated departure/completion")
	panel.get_node("%Journal").pressed.emit()
	_expect(session.mode == NarrativeSession.JOURNAL and main.get_node("JournalPanel/%Close").text == "К паузе между сменами" and panel.get_node("Screen").visible and not panel.get_node("%Actions").visible, "Home diary has correct return and backdrop without overlapping controls")
	session.open_menu()
	session.resume_menu()
	session.close_journal()
	_expect(session.mode == NarrativeSession.HOME and panel.get_node("Screen").visible, "Diary and menu return home")
	var fresh_requests: Array[bool] = []
	session.new_shift_requested.connect(func() -> void: fresh_requests.append(true))
	panel.travel_seconds = 0.1
	panel.get_node("%Work").pressed.emit()
	_expect(session.mode == NarrativeSession.TRAVEL and not session.go_to_work(), "Return begins and rejects double click")
	_expect(not session.finish_commute(home_id), "Old home ID cannot finish return")
	var old_ref: WeakRef = weakref(main)
	await create_timer(0.3).timeout
	await process_frame
	var fresh := current_scene
	_expect(old_ref.get_ref() == null and fresh != null and fresh_requests.size() == 1, "Timer reloads actual scene exactly once")
	if fresh != null:
		var fresh_session := fresh.get_node("NarrativeSession") as NarrativeSession
		_expect(fresh_session.mode == NarrativeSession.EXPLORATION and fresh_session.shift.remaining == 2 and fresh_session.commute.state == CommuteFlow.AT_WORK, "New test shift is ready")
		_expect(not fresh_session.service.served and fresh_session.journal.get_entries().is_empty() and fresh.get_node("AnchorCamera").current_anchor_id == &"entry", "Test reset clears old models and starts at entry")
		presentation = fresh.get_node("Presentation")
		_expect(not presentation.is_retro_enabled() and presentation.get_ambience_gain() == 0, "Presentation preferences survive commute")
		presentation.set_retro_enabled(true)
		presentation.set_ambience_gain(0.35)
		fresh.queue_free()
		await process_frame
