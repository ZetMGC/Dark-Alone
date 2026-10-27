extends Node
## Текущий игровой путь верстака, мышь и независимая проверка подачи состава.

var _checks: int = 0
var _failures: int = 0
var _capture: String = ""
var _mouse := Vector2.ZERO


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
		get_viewport().push_input(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _move(bench: DrinkWorkbench, logical: Vector2) -> void:
	var point := bench.logical_to_screen(logical)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - _mouse
	_mouse = point
	get_viewport().warp_mouse(point)
	get_viewport().push_input(event, true)
	await get_tree().process_frame


func _button(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = _mouse
	event.global_position = _mouse
	get_viewport().push_input(event, true)
	await get_tree().process_frame


func _pour(bench: DrinkWorkbench, id: StringName) -> void:
	await _move(bench, bench.get_item_position(id) + Vector2(0, 15))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _move(bench, Vector2(785, 395))
	for index in 7:
		await _button(MOUSE_BUTTON_WHEEL_UP, true)
	_expect(not bench.stream_info().is_empty() and bench.stream_info().hit, "Mouse pour aims stream inside rim")
	for step in 30:
		bench.advance_pour(0.05)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.preparation.get_snapshot().overall.components.has(str(id)), "Mouse pouring adds real component " + str(id))


func _drag(bench: DrinkWorkbench, id: StringName, destination: Vector2) -> void:
	await _move(bench, bench.get_item_position(id))
	await _button(MOUSE_BUTTON_LEFT, true)
	_expect(bench.get_held_item() == id, "Mouse picks object " + str(id))
	await _move(bench, destination)
	await _button(MOUSE_BUTTON_LEFT, false)
	await get_tree().process_frame


func _snap(label: String) -> void:
	if _capture.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_expect(get_viewport().get_texture().get_image().save_png(_capture.path_join(label + ".png")) == OK, "Capture " + label)


func _run() -> void:
	get_tree().create_timer(35).timeout.connect(func() -> void:
		printerr("FAIL: workbench timed out")
		get_tree().quit(1)
	)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(_capture)
	if "--small" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(960, 600)
	JournalPanel.motion_mode = &"off"
	_test_service_model()
	await _test_controls()
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.preferences_enabled = false
	main.checkpoint_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var service: ServicePanel = main.get_node("ServicePanel")
	var panel: DialogueBubblePanel = main.get_node("DialoguePanel")
	var bench: DrinkWorkbench = service.workbench
	_expect(bench != null and service.workbench_enabled and service.layer < panel.layer, "Current Main enables workbench below speech")
	rig.body.global_position = Vector3(-4.9, 0, -1.2)
	rig.fade_seconds = 0.01
	rig.black_hold_seconds = 0
	await get_tree().physics_frame
	await get_tree().process_frame
	rig.apply_look_delta(Vector2(-PI / 2, 0))
	_expect(main.start_test_dialogue(), "Conversation starts before preparation")
	_expect(rig.request_move(&"back_counter"), "Take rear workstation during dialogue")
	while rig.is_transitioning:
		await get_tree().process_frame
	await _snap("01-back-counter")
	await _key(KEY_B)
	_expect(session.mode == NarrativeSession.SERVICE and bench.visible and not service.get_node("Screen/Card").visible, "B opens free workbench instead of menu")
	bench.set_process(false)
	await _drag(bench, &"spoon", bench.get_item_position(&"cup") + Vector2(34, -10))
	await _pour(bench, &"test_heavy")
	await _pour(bench, &"test_base")
	await _pour(bench, &"test_light")
	_expect(bench.preparation.get_snapshot().layers.size() == 3 and session.shift.remaining == 2, "Gentle flow over attached spoon produces three layers without time cost")
	await _snap("02-layered-workbench")
	var before := bench.preparation.get_volume_ml()
	await _move(bench, bench.get_item_position(&"test_base") + Vector2(0, 15))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _move(bench, Vector2(270, 265))
	await _button(MOUSE_BUTTON_RIGHT, true)
	for step in 8:
		bench.advance_pour(0.05)
	await _button(MOUSE_BUTTON_RIGHT, false)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.get_spilled_ml() > 0 and is_equal_approx(before, bench.preparation.get_volume_ml()), "Missing stream spills without filling cup")
	var node := session.runner.current_node_id
	var text: RichTextLabel = panel.get_node("%VoiceText")
	var typed := text.visible_characters
	await get_tree().create_timer(0.15).timeout
	_expect(session.runner.active and session.runner.current_node_id == node and panel.screen.visible and text.visible_characters >= typed, "NPC speech continues above workbench")
	var draft := bench.preparation.get_snapshot()
	await _key(KEY_J)
	_expect(session.mode == NarrativeSession.JOURNAL and not bench.visible, "Journal pauses surface")
	bench.advance_pour(10)
	_expect(bench.preparation.get_snapshot() == draft, "Hidden workbench cannot pour")
	session.close_journal()
	_expect(session.mode == NarrativeSession.SERVICE and bench.preparation.get_snapshot() == draft, "Journal resumes same portion")
	session.open_menu()
	_expect(not bench.begin_drag(&"test_base", Vector2.ZERO), "Menu blocks workbench commands")
	session.resume_menu()
	bench._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(not bench.begin_drag(&"cup", bench.get_item_position(&"cup")), "Focus loss blocks object pickup")
	bench._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _key(KEY_ESCAPE)
	_expect(session.mode == NarrativeSession.DIALOGUE and rig.focus_active and bench.preparation.get_snapshot() == draft, "Escape stores draft and returns same conversation")
	await _key(KEY_B)
	_expect(bench.preparation.get_snapshot() == draft, "Reenter keeps all three layers")
	await _drag(bench, &"spoon", bench.get_item_position(&"cup") + Vector2(34, -10))
	var spoon := bench.get_item_position(&"cup") + Vector2(34, -10)
	await _move(bench, spoon)
	await _button(MOUSE_BUTTON_LEFT, true)
	_expect(bench.get_held_item() == &"spoon", "Mouse picks spoon attached to rim")
	for point in [Vector2(770, 485), Vector2(860, 485), Vector2(770, 500), Vector2(850, 500)]:
		await _move(bench, point)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.preparation.get_snapshot().structure == "homogeneous", "Spoon gesture actually mixes composition")
	await _drag(bench, &"cup", bench.get_item_position(&"shaker"))
	_expect(bench.is_in_shaker(), "Transfer portion into shaker")
	var amount := bench.preparation.get_volume_ml()
	await _drag(bench, &"cup", DrinkWorkbench.SINK.get_center())
	_expect(bench.is_in_shaker() and bench.preparation.get_volume_ml() == amount, "Empty glass cannot discard contents of shaker")
	var shaker := bench.get_item_position(&"shaker")
	await _move(bench, shaker + Vector2(0, 25))
	await _button(MOUSE_BUTTON_LEFT, true)
	_expect(bench.get_held_item() == &"shaker", "Mouse picks loaded shaker")
	for step in 6:
		await _move(bench, shaker + Vector2(65 if step % 2 == 0 else -65, 25))
	await _move(bench, Vector2(748, 335))
	await _button(MOUSE_BUTTON_RIGHT, true)
	_expect(bench.stream_info().hit, "Shaker return aimed at glass")
	bench.advance_pour(0.05)
	await _button(MOUSE_BUTTON_RIGHT, false)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(not bench.is_in_shaker() and bench.preparation.get_volume_ml() == amount, "Shaker return conserves portion")
	var operations: Array = bench.preparation.get_snapshot().operations
	_expect(operations.any(func(item: Dictionary) -> bool: return item.operation == "shake"), "Shaking gesture recorded in recipe history")
	await _snap("03-mixed-workbench")
	# Пауза над подносом не должна случайно подать напиток.
	bench.begin_drag(&"cup", bench.get_item_position(&"cup"))
	bench.drag_to(DrinkWorkbench.SERVE_ZONE.get_center())
	session.open_menu()
	_expect(not session.service.served and bench.preparation.get_result().is_empty(), "Menu cancels pending drop without serving")
	session.resume_menu()
	var prepared := bench.preparation.get_snapshot()
	await _drag(bench, &"cup", DrinkWorkbench.SERVE_ZONE.get_center())
	_expect(session.service.served and session.shift.remaining == 1 and session.runner.current_node_id == node and session.mode == NarrativeSession.DIALOGUE, "Drop on tray serves real drink and keeps conversation")
	_expect(session.service.get_prepared_drink().overall == prepared.overall and not bench.preparation.get_result().is_empty(), "Guest receives exact sealed composition")
	_expect(not session.serve_preparation(bench.preparation) and session.shift.get_events().size() == 1, "Duplicate delivery rejected")
	await _key(KEY_ESCAPE)
	await get_tree().create_timer(0.08).timeout
	if DisplayServer.get_name() != "headless":
		get_window().grab_focus()
		await get_tree().process_frame
	rig.reset_look()
	var forward := -rig.view.global_basis.z
	var desired: Vector3 = (main.get_node("DialogueTrigger").global_position - rig.view.global_position).normalized()
	rig.apply_look_delta(Vector2(atan2(-desired.x, -desired.z) - atan2(-forward.x, -forward.z), 0))
	await _key(KEY_F)
	await _key(KEY_2)
	# Число страниц зависит от окна; каждое F раскрывает/перелистывает
	# реальную реплику, пока терминальный узел не закончит разговор.
	for page in 12:
		if session.mode == NarrativeSession.SHIFT_COMPLETE:
			break
		await _key(KEY_F)
	if session.mode != NarrativeSession.SHIFT_COMPLETE:
		printerr("DETAIL: mode=%s node=%s remaining=%d looking=%s can_answer=%s forward=%s" % [session.mode, session.runner.current_node_id, session.shift.remaining, panel.looking_at_speaker, panel.can_answer(), -rig.view.global_basis.z])
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE and session.shift.remaining == 0 and session.shift.get_events().size() == 2, "Real prepared drink and dialogue finish same two-division shift")
	JournalPanel.motion_mode = &"full"
	print("%s: drink workbench, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_controls() -> void:
	var bench := DrinkWorkbench.new()
	get_tree().root.add_child(bench)
	bench.set_active(true)
	bench.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	await _move(bench, Vector2(175, 520))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.preparation.get_snapshot().vessel.id == "test_glass", "Mouse selects tall glass from clean rack")
	bench.begin_drag(&"test_heavy", bench.get_item_position(&"test_heavy"))
	bench.drag_to(Vector2(785, 380))
	bench.tilt_by(49)
	bench.advance_pour(0.05)
	bench.set_active(false)
	var before := bench.preparation.get_snapshot()
	var paused_stock := bench.get_bottle_remaining(&"test_heavy")
	_expect(before.overall.volume_ml > 0, "Pause flushes liquid already poured")
	bench.advance_pour(1)
	_expect(bench.preparation.get_snapshot() == before and bench.get_bottle_remaining(&"test_heavy") == paused_stock and not bench.select_vessel(&"test_shot"), "Pause blocks stream, stock use and vessel change")
	bench.set_active(true)
	_expect(bench.stream_info().is_empty(), "Returning from pause does not restart held stream")
	bench.begin_drag(&"test_base", bench.get_item_position(&"test_base"))
	bench.drag_to(Vector2(748, 310))
	bench.tilt_by(90)
	var overflow_stock := bench.get_bottle_remaining(&"test_base")
	var overflow_volume := bench.preparation.get_volume_ml()
	var overflow_waste := bench.get_spilled_ml()
	for step in 250:
		bench.advance_pour(0.05)
	bench.end_drag()
	_expect(is_equal_approx(bench.preparation.get_volume_ml(), 240) and bench.get_spilled_ml() > 0, "Overflow stays on table rather than overfilling model")
	_expect(is_equal_approx(overflow_stock - bench.get_bottle_remaining(&"test_base"), bench.preparation.get_volume_ml() - overflow_volume + bench.get_spilled_ml() - overflow_waste), "Overfilled glass consumes all exiting bottle contents")
	_expect(not bench.select_vessel(&"test_shot"), "Nonempty portion cannot disappear when selecting glass")
	await _drag(bench, &"cup", DrinkWorkbench.SINK.get_center())
	_expect(bench.preparation.get_volume_ml() == 0, "Dropping cup into sink empties actual composition")
	await _move(bench, Vector2(75, 520))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.preparation.get_snapshot().vessel.id == "test_shot", "Empty portion can choose shot glass")
	# Регрессия: реальный стакан перекрывает обе зоны выбора чистой посуды.
	for left in [Vector2(75, 475), Vector2(175, 475)]:
		await _drag(bench, &"cup", left)
		var unchanged := bench.preparation
		await _drag(bench, &"cup", Vector2(810, 440))
		_expect(bench.preparation == unchanged, "Glass at left rack is picked without replacing portion")
	await _pour(bench, &"test_heavy")
	await _pour(bench, &"test_light")
	_expect(bench.preparation.get_snapshot().layers.size() == 1, "Direct gentle pour without spoon mixes compatible liquids")
	var stock := bench.get_bottle_remaining(&"test_heavy")
	var volume := bench.preparation.get_volume_ml()
	var waste := bench.get_spilled_ml()
	bench.begin_drag(&"test_heavy", bench.get_item_position(&"test_heavy"))
	bench.drag_to(Vector2(785, 380))
	bench.tilt_by(49)
	for step in 20:
		bench.advance_pour(0.05)
	bench.end_drag()
	_expect(is_equal_approx(stock - bench.get_bottle_remaining(&"test_heavy"), bench.preparation.get_volume_ml() - volume + bench.get_spilled_ml() - waste), "Bottle loss equals accepted liquid plus overflow")
	# Инерция не зависит от частоты мыши: импульс, затухание, затем остановка паузой.
	bench.begin_drag(&"test_heavy", bench.get_item_position(&"test_heavy"))
	bench.drag_to(bench.get_item_position(&"test_heavy") + Vector2(160, 0))
	bench.advance_motion(0.016)
	var swing := bench.get_bottle_angle(&"test_heavy")
	_expect(absf(swing) > 0.5, "Cursor impulse swings held bottle")
	for step in 400:
		bench.advance_motion(0.016)
	_expect(absf(bench.get_bottle_angle(&"test_heavy")) < 0.1, "Bottle swing damps when cursor stops")
	bench.drag_to(bench.get_item_position(&"test_heavy") + Vector2(-160, 0))
	bench.advance_motion(0.016)
	bench.set_active(false)
	bench.advance_motion(1)
	_expect(bench.get_held_item() == &"" and bench.get_bottle_angle(&"test_heavy") == 0, "Pause stops bottle inertia and hold")
	bench.set_active(true)
	# Пролив на разной глубине стола, а не у нижнего края окна.
	var endpoints: Array[Vector2] = []
	for height in [230, 400]:
		bench.begin_drag(&"test_base", bench.get_item_position(&"test_base"))
		bench.drag_to(Vector2(300, height))
		bench.tilt_by(70)
		endpoints.append(bench.stream_info().end)
		bench.advance_pour(0.05)
		bench.end_drag()
	_expect(endpoints[0].y < endpoints[1].y and endpoints[0].y >= 410 and endpoints[1].y <= 620, "Spill hits local table depth")
	var patches := bench.get_spill_patches()
	bench.advance_motion(0.05)
	_expect(not patches.is_empty() and bench.get_spill_patches().back().spread > patches.back().spread, "Puddle spreads on table after impact")
	patches.back().volume_ml = -100
	_expect(bench.get_spill_patches().back().volume_ml > 0, "Spill snapshots are isolated")
	bench.begin_drag(&"test_base", bench.get_item_position(&"test_base"))
	bench.drag_to(Vector2(300, 300))
	bench.tilt_by(70)
	bench.advance_pour(0.05)
	await _snap("04-spill-on-surface")
	bench.end_drag()
	stock = bench.get_bottle_remaining(&"test_base")
	waste = bench.get_spilled_ml()
	bench.begin_drag(&"test_base", bench.get_item_position(&"test_base"))
	bench.drag_to(Vector2(300, 300))
	bench.tilt_by(90)
	for step in 1000:
		bench.advance_pour(0.05)
	_expect(bench.get_bottle_remaining(&"test_base") == 0 and bench.stream_info().is_empty(), "Empty bottle stops stream and cannot become negative")
	_expect(is_equal_approx(bench.get_spilled_ml() - waste, stock), "Missed liquid consumes exact finite bottle stock")
	bench.end_drag()
	stock = bench.get_bottle_remaining(&"test_heavy")
	await _drag(bench, &"cup", DrinkWorkbench.SINK.get_center())
	bench.select_vessel(&"test_glass")
	bench.set_active(false)
	bench.set_active(true)
	_expect(bench.get_bottle_remaining(&"test_base") == 0 and bench.get_bottle_remaining(&"test_heavy") == stock, "Vessel selection and reopen never refill bottles")
	bench.set_active(false)
	bench.queue_free()
	await get_tree().process_frame


func _test_service_model() -> void:
	var catalog := DrinkMaterialCatalog.new()
	catalog.load_file(DrinkWorkbench.MATERIALS)
	var stock := DrinkBottleStock.new()
	_expect(stock.withdraw(&"test_base", 5) == 0 and not stock.configure(catalog, NAN), "Stock rejects unconfigured use and nonfinite capacity")
	_expect(stock.configure(catalog, 10) and not stock.configure(catalog, 20), "Stock configured once per shift")
	_expect(stock.withdraw(&"missing", 5) == 0 and stock.withdraw(&"test_base", -1) == 0 and stock.withdraw(&"test_base", INF) == 0 and stock.get_remaining(&"test_base") == 10, "Invalid stock requests preserve contents")
	_expect(stock.withdraw(&"test_base", 12) == 10 and stock.withdraw(&"test_base", 1) == 0 and stock.get_remaining(&"test_base") == 0 and stock.get_remaining(&"test_light") == 10, "Stock clamps withdrawal and isolates bottles")
	var prep := DrinkPreparation.new()
	prep.configure(catalog, &"test_shot", &"service_model_test")
	prep.pour(&"pour", &"test_base", 10)
	var service := GuestService.new()
	_expect(not service.serve_preparation(prep) and prep.get_result().is_empty(), "Unconfigured guest does not seal drink")
	service.configure(&"test_guest", [{"id": "test_water", "title": "[TEST] Вода", "description": "Вода"}])
	_expect(not service.serve_preparation(null), "Missing portion rejected")
	_expect(service.serve_preparation(prep) and service.selected_drink_id == &"prepared_drink", "Prepared service is distinct from menu ID")
	var copy := service.get_prepared_drink()
	copy.overall.components.test_base = 999
	_expect(service.get_prepared_drink().overall.components.test_base == 10 and not service.serve_preparation(prep), "Prepared result isolated and delivered once")
