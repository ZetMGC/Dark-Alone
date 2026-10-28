extends Node
## Совместный default-путь: новый бар → пометки книги → новый дом → следующая смена.

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	get_tree().create_timer(30).timeout.connect(func() -> void: get_tree().quit(1))
	JournalPanel.motion_mode = &"off"
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.preferences_enabled = false
	main.checkpoint_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var main_id: int = main.get_instance_id()
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	rig.body.global_position = Vector3(-4.9, 0, -1.2)
	rig.fade_seconds = 0.01
	rig.black_hold_seconds = 0
	await get_tree().physics_frame
	await get_tree().process_frame
	rig.apply_look_delta(Vector2(-PI / 2, 0))
	_expect(main.start_test_dialogue(), "Default walking conversation starts")
	rig.apply_look_delta(Vector2(PI / 2, 0))
	await get_tree().process_frame
	_expect(main.get_node("DialoguePanel").edge_mode, "Perpendicular speaker stays at edge without invalid projection")
	_expect(rig.request_move(&"back_counter"), "Backbar focus during conversation")
	while rig.is_transitioning:
		await get_tree().process_frame
	_expect(main.open_service_menu(), "New preparation opens with active dialogue")
	var bench: DrinkWorkbench = main.get_node("ServicePanel").workbench
	_expect(bench != null and session.runner.active, "Workbench and runner coexist")
	_expect(session.open_journal(true) and session.select_journal_entry(&"test_signal"), "New book opens during preparation")
	for frame in 4:
		await get_tree().process_frame
	var text = main.get_node("JournalPanel/%Description")
	text.annotation_requested.emit(&"underline", 0, 6)
	var marks := session.journal.get_annotations(&"test_signal")
	_expect(not marks.is_empty() and text.editing_enabled, "New ink UI annotates current entry")
	_expect(session.close_journal() and session.mode == NarrativeSession.SERVICE, "Journal restores same workbench context")
	_expect(bench.preparation.pour(&"integration_drink", &"test_base", 20), "Prepare actual composition")
	bench.begin_drag(&"cup", bench.get_item_position(&"cup"))
	bench.drag_to(DrinkWorkbench.SERVE_ZONE.get_center())
	bench.end_drag()
	_expect(bench.is_ready_to_deliver() and not session.service.served, "Tray only stages portion")
	bench.get_node("DeliverDrink").pressed.emit()
	_expect(session.service.served and session.shift.remaining == 1 and session.mode == NarrativeSession.DIALOGUE, "Confirmed delivery preserves conversation and costs once")
	_expect(session.choose_for_node(&"test_guest_intro", &"opening", &"leave") and session.finish_for_node(&"test_guest_intro", &"goodbye"), "Conversation finishes after drink")
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE and session.shift.remaining == 0, "Combined two-division shift finishes")
	_expect(session.go_home() and session.finish_commute(session.commute.trip_id), "Commute reaches new home")
	await get_tree().process_frame
	_expect(session.mode == NarrativeSession.HOME and main.get_node("HomeExploration").visible, "New home is active")
	_expect(session.open_journal(true), "Home journal opens")
	for frame in 4:
		await get_tree().process_frame
	_expect(session.journal.get_annotations(&"test_signal") == marks, "Ink survives bar to home")
	session.close_journal()
	_expect(session.go_to_work() and session.finish_commute(session.commute.trip_id), "Return starts ordinary next shift")
	for frame in 5:
		await get_tree().process_frame
	var next := get_tree().current_scene
	var next_session: NarrativeSession = next.get_node("NarrativeSession")
	_expect(next.get_instance_id() != main_id and next_session.shift.remaining == 2 and not next_session.service.served, "Fresh shift restores clock and guest")
	_expect(next_session.journal.get_annotations(&"test_signal") == marks, "Next shift retains colleague journal annotations")
	var next_bench: DrinkWorkbench = next.get_node("ServicePanel").workbench
	_expect(next_bench.preparation.get_volume_ml() == 0 and next_bench.get_bottle_remaining(&"test_base") == 500, "New shift resets drink workbench independently of journal")
	JournalPanel.motion_mode = &"full"
	print("%s: release integration, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
