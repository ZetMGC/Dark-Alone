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
	# Только одна очередь ввода: OS warp порождает вторую, запаздывающую
	# очередь motion и искажает drag/клик в растянутом маленьком окне.
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
	_test_spills()
	await _test_pour_control()
	await _test_controls()
	await _test_mixing_surface()
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
	await _move(bench, Vector2(50, 265))
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
	var before_transfer := bench.preparation.get_volume_ml()
	await _drag(bench, &"cup", bench.get_item_position(&"shaker"))
	_expect(not bench.is_in_shaker() and bench.preparation.get_volume_ml() == before_transfer, "Dropping glass on shaker no longer teleports liquid")
	_expect(bench.get_shaker_state() == &"open", "Shaker starts open for filling")
	await _move(bench, bench.get_item_position(&"cup"))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _move(bench, bench.get_item_position(&"shaker") + Vector2(-62, -105))
	await _button(MOUSE_BUTTON_RIGHT, true)
	_expect(bench.stream_info().get("hit", false) and bench.stream_info().get("target") == &"shaker", "Actual visible stream enters open shaker mouth")
	for step in 200:
		bench.advance_pour(0.05)
	await _button(MOUSE_BUTTON_RIGHT, false)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.is_in_shaker() and bench.preparation.get_volume_ml() < DrinkPreparation.MIN_DOSE_ML, "Continuous pouring fills independent shaker")
	await _drag(bench, &"cup", Vector2(810, 440))
	await _snap("10-shaker-open")
	bench.begin_drag(&"shaker", bench.get_item_position(&"shaker"))
	for step in 6:
		bench.drag_to(bench.get_item_position(&"shaker") + Vector2(30 if step % 2 == 0 else -30, 0))
	_expect(bench.get_container_snapshot(&"shaker").technique.shaken_s == 0, "Open shaker cannot magically shake liquid")
	_expect(not bench.toggle_shaker_lid(), "Cannot operate lid while holding vessel")
	bench.end_drag()
	var lid: Button = bench.get_node("ShakerLid")
	await _move(bench, (lid.position + lid.size * 0.5 - bench._origin) / bench._scale)
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.get_shaker_state() == &"sealed", "Actual lid button closes shaker")
	await _snap("11-shaker-closed")
	var closed_volume: float = bench.get_container_snapshot(&"shaker").overall.volume_ml
	var stock_before := bench.get_bottle_remaining(&"test_base")
	var spill_before := bench.get_spilled_ml()
	bench.begin_drag(&"test_base", bench.get_item_position(&"test_base"))
	bench.drag_to(bench.get_item_position(&"shaker") + Vector2(-58, -140))
	bench.tilt_by(70)
	_expect(bench.stream_info().get("blocked", false), "Closed shaker lid intercepts stream")
	for step in 10:
		bench.advance_pour(0.05)
	bench.end_drag()
	_expect(bench.get_container_snapshot(&"shaker").overall.volume_ml == closed_volume and bench.get_bottle_remaining(&"test_base") < stock_before and bench.get_spilled_ml() > spill_before, "Pour on lid consumes stock into spill without filling sealed shaker")
	var ice_before: float = bench.get_container_snapshot(&"shaker").technique.ice_ml
	bench.begin_drag(&"ice", bench.get_item_position(&"ice"))
	bench.drag_to(bench.get_item_position(&"shaker"))
	bench.end_drag()
	_expect(bench.get_container_snapshot(&"shaker").technique.ice_ml == ice_before, "Ice cannot pass through closed lid")
	var amount: float = bench.get_container_snapshot(&"shaker").overall.volume_ml
	await _drag(bench, &"cup", DrinkWorkbench.SINK.get_center())
	_expect(bench.is_in_shaker() and bench.preparation.get_volume_ml() == 0 and bench.get_container_snapshot(&"shaker").overall.volume_ml == amount, "Empty glass cannot discard independent contents of shaker")
	var shaker := bench.get_item_position(&"shaker")
	await _move(bench, shaker + Vector2(0, 25))
	await _button(MOUSE_BUTTON_LEFT, true)
	_expect(bench.get_held_item() == &"shaker", "Mouse picks loaded shaker")
	for step in 6:
		await _move(bench, shaker + Vector2(65 if step % 2 == 0 else -65, 25))
	await _button(MOUSE_BUTTON_RIGHT, true)
	_expect(bench.stream_info().is_empty(), "Sealed cap prevents pouring")
	await _button(MOUSE_BUTTON_RIGHT, false)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.toggle_shaker_cap() and bench.get_shaker_state() == &"straining", "Remove cap before straining")
	await _snap("12-shaker-straining")
	await _move(bench, bench.get_item_position(&"shaker") + Vector2(0, 25))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _move(bench, Vector2(748, 335))
	await _button(MOUSE_BUTTON_RIGHT, true)
	_expect(bench.stream_info().get("hit", false), "Shaker strainer return aimed at glass")
	for step in 200:
		bench.advance_pour(0.05)
	await _button(MOUSE_BUTTON_RIGHT, false)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(not bench.is_in_shaker() and is_equal_approx(bench.preparation.get_volume_ml(), amount), "Continuous shaker return conserves portion")
	var operations: Array = bench.preparation.get_snapshot().operations
	_expect(bench.preparation.get_snapshot().technique.shaken_s > 0 and operations.any(func(item: Dictionary) -> bool: return item.operation == "transfer_in"), "Shaking provenance survives straining into serving glass")
	await _snap("03-mixed-workbench")
	# Дать инструментам успокоиться перед передачей.
	bench.set_process(true)
	await get_tree().create_timer(0.45).timeout
	bench.set_process(false)
	# Пауза над подносом не должна случайно подать напиток.
	bench.begin_drag(&"cup", bench.get_item_position(&"cup"))
	bench.drag_to(DrinkWorkbench.SERVE_ZONE.get_center())
	session.open_menu()
	_expect(not session.service.served and bench.preparation.get_result().is_empty(), "Menu cancels pending drop without serving")
	session.resume_menu()
	var prepared := bench.preparation.get_snapshot()
	await _drag(bench, &"cup", DrinkWorkbench.SERVE_ZONE.get_center())
	_expect(bench.is_ready_to_deliver() and not session.service.served and session.shift.remaining == 2, "Drop stages drink without spending shift time")
	await _snap("05-ready-for-delivery")
	if DisplayServer.get_name() != "headless":
		get_window().grab_focus()
		await get_tree().process_frame
		await get_tree().process_frame
	await _move(bench, Vector2(1080, 438))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(session.service.served and session.shift.remaining == 1 and session.runner.current_node_id == node and session.mode == NarrativeSession.DIALOGUE, "Delivery button serves real drink and keeps conversation")
	var guest: ServiceGuest = main.get_node("DialogueTrigger")
	_expect(guest.get_node("ServedGlass").visible and guest.get_node("ServedGlass/DrinkLayer0") != null, "Actual drink appears on counter in front of guest")
	var served_glass: MeshInstance3D = guest.get_node("ServedGlass/Cup")
	_expect(served_glass.global_position.x > -4.325 and served_glass.global_position.x < -2.875 and is_equal_approx(served_glass.global_position.y - served_glass.mesh.height / 2, 1.16), "Prepared glass rests on actual counter top")
	_expect(session.service.get_prepared_drink().overall == prepared.overall and not bench.preparation.get_result().is_empty(), "Guest receives exact sealed composition")
	if session.service.served:
		_expect(not session.serve_preparation(bench.preparation) and session.shift.get_events().size() == 1, "Duplicate delivery rejected")
	else:
		_expect(false, "Duplicate delivery requires successful original delivery")
	await _key(KEY_ESCAPE)
	await get_tree().create_timer(0.08).timeout
	if DisplayServer.get_name() != "headless":
		get_window().grab_focus()
		await get_tree().process_frame
	rig.reset_look()
	var forward := -rig.view.global_basis.z
	var desired: Vector3 = (main.get_node("DialogueTrigger").global_position - rig.view.global_position).normalized()
	rig.apply_look_delta(Vector2(atan2(-desired.x, -desired.z) - atan2(-forward.x, -forward.z), 0))
	await _snap("06-drink-at-guest")
	await _key(KEY_E)
	await _key(KEY_2)
	# Число страниц зависит от окна; каждое F раскрывает/перелистывает
	# реальную реплику, пока терминальный узел не закончит разговор.
	for page in 12:
		if session.mode == NarrativeSession.SHIFT_COMPLETE:
			break
		await _key(KEY_E)
	if session.mode != NarrativeSession.SHIFT_COMPLETE:
		printerr("DETAIL: mode=%s node=%s remaining=%d looking=%s can_answer=%s forward=%s" % [session.mode, session.runner.current_node_id, session.shift.remaining, panel.looking_at_speaker, panel.can_answer(), -rig.view.global_basis.z])
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE and session.shift.remaining == 0 and session.shift.get_events().size() == 2, "Real prepared drink and dialogue finish same two-division shift")
	JournalPanel.motion_mode = &"full"
	print("%s: drink workbench, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_pour_control() -> void:
	var bench := DrinkWorkbench.new()
	get_tree().root.add_child(bench)
	bench.set_active(true)
	bench.set_process(false)
	await get_tree().process_frame
	await _drag(bench, &"spoon", bench.get_item_position(&"cup") + Vector2(34, -10))
	await _move(bench, bench.get_item_position(&"test_light"))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _move(bench, Vector2(785, 395))
	for index in 5:
		await _button(MOUSE_BUTTON_WHEEL_UP, true)
	_expect(bench.stream_info().is_empty(), "Wheel before pour threshold keeps bottle closed")
	await _button(MOUSE_BUTTON_WHEEL_UP, true)
	var slow := bench.stream_info()
	_expect(not slow.is_empty() and slow.rate <= 4 and slow.hit, "Small wheel tilt produces actual low flow into cup")
	_expect(bench._pour_hint(slow).contains("По каплям") and bench._pour_hint(slow).contains("по ложке"), "Slow pour explains drop flow and actual spoon hit")
	await _snap("08-drop-pour")
	var before := bench.get_bottle_remaining(&"test_light")
	for step in 10:
		bench.advance_pour(0.05)
	var slow_used := before - bench.get_bottle_remaining(&"test_light")
	for index in 4:
		await _button(MOUSE_BUTTON_WHEEL_UP, true)
	var fast := bench.stream_info()
	_expect(fast.rate > slow.rate * 3 and bench._pour_hint(fast).contains("Сильная струя"), "Larger wheel tilt increases real flow and visible intensity state")
	await _snap("09-strong-pour")
	before = bench.get_bottle_remaining(&"test_light")
	for step in 10:
		bench.advance_pour(0.05)
	_expect(before - bench.get_bottle_remaining(&"test_light") > slow_used * 3, "Same pour duration consumes more actual stock at higher tilt")
	for index in 5:
		await _button(MOUSE_BUTTON_WHEEL_DOWN, true)
	_expect(bench.stream_info().is_empty(), "Reverse wheel straightens held bottle and stops stream")
	before = bench.get_bottle_remaining(&"test_light")
	bench.advance_pour(0.05)
	_expect(bench.get_bottle_remaining(&"test_light") == before, "Stopped tilt consumes no stock while bottle is still held")
	await _button(MOUSE_BUTTON_LEFT, false)
	bench.set_active(false)
	bench.queue_free()
	await get_tree().process_frame


func _test_controls() -> void:
	var bench := DrinkWorkbench.new()
	get_tree().root.add_child(bench)
	bench.set_active(true)
	bench.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	for item in [&"cup", &"spoon", &"shaker"]:
		var position := bench.get_item_position(item)
		bench.begin_drag(item, position)
		bench.drag_to(position + Vector2(100, 0))
		bench.advance_motion(0.016)
		_expect(absf(bench.get_item_angle(item)) > 0.1, "Held object has cursor inertia: " + str(item))
		for step in 350:
			bench.advance_motion(0.016)
		_expect(absf(bench.get_item_angle(item)) < 0.1, "Object inertia settles: " + str(item))
		bench.drag_to(position)
		bench.end_drag()
	var standing := bench.get_item_position(&"test_equal")
	var saved_stock := bench.get_bottle_remaining(&"test_equal")
	bench.begin_drag(&"test_base", bench.get_item_position(&"test_base"))
	bench.drag_to(standing)
	bench.advance_motion(0.016)
	_expect(absf(bench.get_item_angle(&"test_equal")) > 0.1 and bench.get_item_position(&"test_equal") == standing and bench.get_bottle_remaining(&"test_equal") == saved_stock, "Passing bottle nudges standing glass without moving or losing contents")
	bench.end_drag()
	for step in 300:
		bench.advance_motion(0.016)
	_expect(absf(bench.get_item_angle(&"test_equal")) < 0.1, "Standing bottle nudge damps")
	bench.begin_drag(&"test_base", bench.get_item_position(&"test_base"))
	bench.drag_to(standing + Vector2(0, -100))
	bench.drag_to(standing)
	bench.advance_motion(0.016)
	_expect(absf(bench.get_item_angle(&"test_equal")) > 0.1, "Vertical bottle contact also produces gentle nudge")
	bench.end_drag()
	# Отдельные кнопки работают независимо от предметов в зоне чистой посуды.
	await _move(bench, Vector2(245, 607))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.preparation.get_snapshot().vessel.id == "test_glass", "Explicit button chooses tall glass")
	await _move(bench, Vector2(95, 607))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.preparation.get_snapshot().vessel.id == "test_shot", "Explicit button switches back to shot")
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
	await _move(bench, Vector2(95, 607))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.preparation.get_volume_ml() == 240 and bench.preparation.get_snapshot().vessel.id == "test_glass", "Blocked vessel button preserves full portion")
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
		bench.drag_to(Vector2(50, height))
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
	bench.drag_to(Vector2(50, 300))
	bench.tilt_by(70)
	bench.advance_pour(0.05)
	await _snap("04-spill-on-surface")
	bench.end_drag()
	stock = bench.get_bottle_remaining(&"test_base")
	waste = bench.get_spilled_ml()
	bench.begin_drag(&"test_base", bench.get_item_position(&"test_base"))
	bench.drag_to(Vector2(50, 300))
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
	bench.preparation.pour(&"rejected_delivery", &"test_heavy", 5)
	await _drag(bench, &"cup", DrinkWorkbench.SERVE_ZONE.get_center())
	var staged := bench.preparation.get_snapshot()
	_expect(bench.is_ready_to_deliver() and not bench.request_delivery() and bench.preparation.get_result().is_empty() and bench.preparation.get_snapshot() == staged, "Rejected delivery preserves staged drink without sealing")
	bench.set_active(false)
	bench.set_active(true)
	_expect(bench.is_ready_to_deliver() and not bench.request_delivery(), "Reopen preserves staged portion and rejection remains safe")
	bench.set_active(false)
	bench.queue_free()
	await get_tree().process_frame


func _test_mixing_surface() -> void:
	var bench := DrinkWorkbench.new()
	get_tree().root.add_child(bench)
	bench.set_active(true)
	bench.set_process(false)
	await get_tree().process_frame
	await _pour(bench, &"test_heavy")
	var base := bench.preparation.get_snapshot()
	for ingredient in [&"test_base", &"test_light"]:
		await _move(bench, bench.get_item_position(ingredient) + Vector2(0, 15))
		await _button(MOUSE_BUTTON_LEFT, true)
		await _move(bench, bench.get_item_position(&"mixing") + Vector2(-25, -45))
		for index in 7:
			await _button(MOUSE_BUTTON_WHEEL_UP, true)
		_expect(bench.stream_info().target == &"mixing", "Mouse aims ingredient into independent mixing glass")
		for step in 30:
			bench.advance_pour(0.05)
		await _button(MOUSE_BUTTON_LEFT, false)
	_expect(bench.preparation.get_snapshot() == base and bench.get_container_snapshot(&"mixing").overall.components.size() == 2, "Preparing premix does not change serving glass")
	await _drag(bench, &"ice", bench.get_container_rect(&"mixing").get_center())
	_expect(bench.get_container_snapshot(&"mixing").technique.ice_ml == 30, "Mouse adds ice only to chosen container")
	await _drag(bench, &"spoon", bench.get_item_position(&"mixing") + Vector2(34, -10))
	await _move(bench, bench.get_item_position(&"mixing") + Vector2(34, -10))
	await _button(MOUSE_BUTTON_LEFT, true)
	for point in [Vector2(520, 480), Vector2(600, 480), Vector2(520, 520), Vector2(600, 520)]:
		await _move(bench, point)
	await _button(MOUSE_BUTTON_LEFT, false)
	var premix := bench.get_container_snapshot(&"mixing")
	_expect(premix.technique.temperature_c < 20 and premix.technique.dilution_ml > 0 and premix.structure == "homogeneous", "Mouse stirring with ice makes real diluted chilled premix")
	await _drag(bench, &"spoon", bench.get_item_position(&"cup") + Vector2(34, -10))
	var stock := bench.get_bottle_remaining(&"test_base")
	await _move(bench, bench.get_item_position(&"mixing") + Vector2(0, 50))
	await _button(MOUSE_BUTTON_LEFT, true)
	await _move(bench, Vector2(785, 380) - Vector2(63, -8).rotated(deg_to_rad(49)) + Vector2(0, 50))
	for index in 7:
		await _button(MOUSE_BUTTON_WHEEL_UP, true)
	_expect(bench.stream_info().target == &"cup", "Mouse tilts premix over spoon in serving glass")
	for step in 30:
		bench.advance_pour(0.05)
	await _snap("07-premix-layer")
	await _button(MOUSE_BUTTON_LEFT, false)
	var result := bench.preparation.get_snapshot()
	var rest := bench.get_container_snapshot(&"mixing")
	_expect(result.layers.size() == 2 and result.layers[1].components.size() == 3 and result.layers[0].components.has("test_heavy"), "Premix is added as its own layer containing both ingredients and meltwater")
	_expect(rest.overall.volume_ml > 0 and rest.technique.ice_ml == premix.technique.ice_ml and is_equal_approx(result.overall.volume_ml + rest.overall.volume_ml, base.overall.volume_ml + premix.overall.volume_ml), "Partial layered pour conserves both containers and leaves spent ice")
	_expect(bench.get_bottle_remaining(&"test_base") == stock, "Pouring premix never charges source bottle twice")
	var saved := bench.get_container_snapshot(&"mixing")
	bench.set_active(false)
	bench.advance_pour(10)
	bench.advance_motion(10)
	bench.set_active(true)
	_expect(bench.get_container_snapshot(&"mixing") == saved and bench.preparation.get_snapshot() == result, "Pause preserves both independent drafts")
	# Пролив смеси сохраняет все составляющие, а не превращает её в один материал.
	bench.begin_drag(&"mixing", bench.get_item_position(&"mixing"))
	bench.drag_to(Vector2(50, 300))
	bench.tilt_by(70)
	var before_waste := bench.get_spilled_ml()
	for step in 4:
		bench.advance_pour(0.05)
	bench.end_drag()
	_expect(bench.get_spilled_ml() > before_waste and bench.get_spill_patches().back().components.size() == 3, "Spilled premix retains real ingredient composition")
	bench.set_active(false)
	bench.queue_free()
	await get_tree().process_frame


func _test_spills() -> void:
	var catalog := DrinkMaterialCatalog.new()
	catalog.load_file(DrinkWorkbench.MATERIALS)
	var surface := DrinkSpillSurface.new()
	_expect(surface.configure(catalog), "Spill model configures")
	_expect(not surface.add_spill({"unknown": 10}, Vector2.ZERO) and not surface.add_spill({"test_heavy": NAN}, Vector2.ZERO) and surface.get_patches().is_empty(), "Invalid spills are atomic")
	surface.add_spill({"test_heavy": 10.0}, Vector2(500, 500))
	surface.add_spill({"test_light": 30.0}, Vector2(500, 500))
	var patch: Dictionary = surface.get_patches()[0]
	_expect(surface.get_patches().size() == 1 and patch.volume_ml == 40 and patch.components.test_heavy == 10 and patch.components.test_light == 30, "Overlapping spills combine actual components and volume")
	var heavy: Array = catalog.get_ingredient(&"test_heavy").color
	var light: Array = catalog.get_ingredient(&"test_light").color
	var expected := (Color(heavy[0], heavy[1], heavy[2], 0.7) + Color(light[0], light[1], light[2], 0.7) * 3) / 4
	_expect(patch.color.is_equal_approx(expected), "Puddle color is volume-weighted mixture")
	patch.components.test_heavy = 999
	_expect(surface.get_patches()[0].components.test_heavy == 10, "Mixed puddle snapshots are isolated")
	var spreading := DrinkSpillSurface.new()
	spreading.configure(catalog)
	spreading.add_spill({"test_heavy": 20.0}, Vector2(800, 500))
	spreading.add_spill({"test_light": 20.0}, Vector2(840, 500))
	_expect(spreading.get_patches().size() == 2, "Separate wet spots remain separate initially")
	for step in 20:
		spreading.advance(0.05)
	_expect(spreading.get_patches().size() == 1 and spreading.get_patches()[0].volume_ml == 40, "Spreading spots join on contact without losing liquid")


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
