extends Node
## Реальные команды стойки и речи; собственная TEST-реплика, без файлов игрока.

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


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _aim(rig: FreeRoamCamera, point: Vector3) -> void:
	rig.reset_look()
	var current := -rig.view.global_basis.z.normalized()
	var direction := (point - rig.view.global_position).normalized()
	rig.apply_look_delta(Vector2(atan2(-direction.x, -direction.z) - atan2(-current.x, -current.z), asin(direction.y) - asin(current.y)))


func _point(rig: FreeRoamCamera, point: Vector3) -> void:
	var event := InputEventMouseMotion.new()
	event.position = rig.view.unproject_position(point)
	event.global_position = event.position
	get_viewport().warp_mouse(event.position)
	get_viewport().push_input(event, true)
	await get_tree().process_frame


func _still(rig: FreeRoamCamera, label: String) -> void:
	var before := rig.body.global_position
	Input.action_press("move_back")
	for frame in 5:
		await get_tree().physics_frame
		await get_tree().process_frame
	Input.action_release("move_back")
	_expect(rig.body.global_position.is_equal_approx(before), "Body paused: " + label)


func _snap(label: String) -> void:
	if _capture.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_expect(get_viewport().get_texture().get_image().save_png(_capture.path_join(label + ".png")) == OK, "Capture " + label)


func _boot(budget: int = 2, long_speech: bool = false) -> Node:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.drink_workbench_enabled = false
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	main.shift_budget = budget
	if long_speech:
		main.dialogue_paths = PackedStringArray(["res://tests/parallel/bar/long_service_guest.json"])
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	rig.fade_seconds = 0.01
	rig.black_hold_seconds = 0
	rig.body.global_position = Vector3(-4.9, 0, -1.2)
	await get_tree().physics_frame
	await get_tree().process_frame
	_aim(rig, main.get_node("DialogueTrigger").global_position)
	return main


func _dispose(main: Node) -> void:
	get_tree().current_scene = null
	main.queue_free()
	await get_tree().process_frame


func _focus(rig: FreeRoamCamera) -> void:
	_aim(rig, Vector3(-5.6, 1.06, -2))
	await _key(KEY_E)
	while rig.is_transitioning:
		await get_tree().process_frame
	_expect(rig.focus_active and rig.current_anchor_id == &"back_counter", "E takes actual back counter during conversation")


func _run() -> void:
	get_tree().create_timer(30).timeout.connect(func() -> void:
		printerr("FAIL: bar service dialogue timed out")
		get_tree().quit(1)
	)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(_capture)
	if "--small" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(960, 600)
	JournalPanel.motion_mode = &"off"
	await _test_conversation_service()
	await _test_reverse_order()
	await _test_time_boundary()
	JournalPanel.motion_mode = &"full"
	print("%s: bar service dialogue, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_conversation_service() -> void:
	var main := await _boot(2, true)
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var panel: DialogueBubblePanel = main.get_node("DialoguePanel")
	var service: ServicePanel = main.get_node("ServicePanel")
	var interaction: InteractionController = main.get_node("InteractionController")
	var text: RichTextLabel = panel.get_node("%VoiceText")
	panel.characters_per_second = 20
	_expect(main.start_test_dialogue(), "Starts conversation")
	_expect(not main.open_service_menu(), "Walking conversation cannot serve remotely")
	await _key(KEY_F)
	await _key(KEY_F)
	_expect(panel.get_page_count() > 2 and panel.get_page_index() == 1 and not panel.is_line_complete(), "Fixture on partially typed continuation")
	var node := session.runner.current_node_id
	var selected := panel.selected_index
	await _focus(rig)
	_expect(session.mode == NarrativeSession.DIALOGUE and session.runner.current_node_id == node and panel.get_page_index() == 1, "Workstation keeps same runner and page")
	_expect(interaction.pointer_mode and not panel.can_answer(), "Cursor workstation disables reply input")
	var basis := rig.view.global_basis
	rig.apply_look_delta(Vector2(0.6, 0.3))
	_expect(rig.view.global_basis.is_equal_approx(basis), "Conversation workstation camera fixed")
	if DisplayServer.get_name() != "headless":
		_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Workstation releases cursor")
	await _still(rig, "dialogue workstation")
	await _key(KEY_F)
	await _key(KEY_2)
	_expect(panel.get_page_index() == 1 and session.runner.current_node_id == node and panel.selected_index == selected, "Workstation F and digits do not act on speech")
	await _point(rig, Vector3(-5.6, 1.12, -2))
	await _key(KEY_E)
	_expect(session.mode == NarrativeSession.SERVICE and session.runner.active and panel.screen.visible, "Cursor E opens drink menu with visible active speech")
	var typed := text.visible_characters
	await get_tree().create_timer(0.15).timeout
	_expect(text.visible_characters > typed and panel.get_page_index() == 1, "NPC continues typing inside service menu")
	_expect(not panel.confirm() and not panel.submit_choice(0) and not panel.advance_page(), "Passive speech rejects direct UI commands")
	await _key(KEY_F)
	await _key(KEY_1)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	get_viewport().push_input(wheel)
	_expect(session.runner.current_node_id == node and panel.selected_index == selected, "Service keys and wheel cannot choose dialogue")
	_expect(not session.choose_for_node(&"test_guest_intro", node, &"leave") and not session.serve_drink(&"missing"), "Modal model rejects answer and invalid drink")
	await _still(rig, "drink selection")
	var bubble: Control = panel.get_node("%VoiceBubble")
	var card: Control = service.get_node("Screen/Card")
	_expect(not bubble.get_global_rect().intersects(card.get_global_rect()) and Rect2(Vector2.ZERO, service.screen.size).encloses(card.get_global_rect()), "Compact menu fits screen without covering bubble")
	var scroll: Control = service.get_node("%Scroll")
	var last_option: Control = service.get_node("%Options").get_child(4)
	_expect(scroll.get_global_rect().encloses(last_option.get_global_rect()), "Both compact drink buttons visible without scrolling")
	await _snap("01-speaking-and-drinks")
	service.get_node("%Menu").pressed.emit()
	_expect(session.mode == NarrativeSession.MENU and not panel.screen.visible and not service.screen.visible, "Menu pauses both overlays")
	typed = text.visible_characters
	await _still(rig, "menu over service")
	_expect(text.visible_characters == typed, "Menu pauses service speech typing")
	await _key(KEY_ESCAPE)
	_expect(session.mode == NarrativeSession.SERVICE and rig.focus_active and panel.screen.visible, "Escape resumes exact service context")
	await _key(KEY_J)
	_expect(session.mode == NarrativeSession.JOURNAL, "Journal opens over concurrent service")
	typed = text.visible_characters
	await _still(rig, "journal over service")
	_expect(text.visible_characters == typed, "Journal pauses service speech typing")
	session.close_journal()
	_expect(session.mode == NarrativeSession.SERVICE and rig.focus_active and panel.get_page_index() == 1, "Journal restores service and reading page")
	panel._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	rig._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	typed = text.visible_characters
	await _still(rig, "focus loss")
	_expect(text.visible_characters == typed, "Focus loss pauses active speech")
	panel._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	rig._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _key(KEY_ESCAPE)
	_expect(session.mode == NarrativeSession.DIALOGUE and rig.focus_active and panel.get_page_index() == 1 and session.shift.remaining == 2, "Cancel service preserves workstation, speech and free time")
	await _key(KEY_ESCAPE)
	_expect(not rig.focus_active and session.mode == NarrativeSession.DIALOGUE, "Second Escape releases workstation without cancelling conversation")
	_aim(rig, main.get_node("DialogueTrigger").global_position)
	for step in 40:
		if panel.is_speech_complete():
			break
		await _key(KEY_F)
	_expect(panel.is_speech_complete() and panel.can_answer(), "Walking look at guest restores continuation and answers")
	panel.select_relative(1)
	selected = panel.selected_index
	_expect(selected == 1, "Choose response before reopening menu")
	await _focus(rig)
	await _key(KEY_B)
	_expect(session.mode == NarrativeSession.SERVICE, "B reopens service after a cancelled visit")
	var button := service.get_node("%Options").get_child(1) as Button
	button.pressed.emit()
	_expect(session.mode == NarrativeSession.DIALOGUE and rig.focus_active and session.runner.current_node_id == node, "Serving returns same active conversation at counter")
	_expect(session.shift.remaining == 1 and session.service.served and main.get_node("DialogueTrigger/ServedGlass").visible, "Serving commits one observable result and one division")
	_expect(panel.selected_index == selected and panel.is_speech_complete(), "Serving preserves selected reply and complete page")
	_expect(not session.serve_drink(&"test_house_drink") and not main.open_service_menu() and session.shift.get_events().size() == 1, "Duplicate serving rejected without extra event")
	await _snap("02-served-still-talking")
	await _key(KEY_ESCAPE)
	_aim(rig, main.get_node("DialogueTrigger").global_position)
	await _key(KEY_F)
	_expect(session.runner.current_node_id == &"goodbye", "F confirms preserved reply after returning gaze")
	await _snap("03-back-to-guest")
	await _key(KEY_F)
	await _key(KEY_F)
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE and not session.runner.active and session.shift.remaining == 0 and session.shift.get_events().size() == 2, "Dialogue then finishes shift with exactly two completed events")
	_expect(not session.finish_for_node(&"test_guest_intro", &"goodbye") and not session.open_service(), "Stale terminal and service requests rejected after shift")
	await _dispose(main)


func _test_reverse_order() -> void:
	var main := await _boot()
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	_expect(main.start_test_dialogue(), "Reverse order starts dialogue")
	session.choose_for_node(&"test_guest_intro", &"opening", &"leave")
	session.finish_for_node(&"test_guest_intro", &"goodbye")
	await _focus(rig)
	_expect(main.open_service_menu() and session.serve_drink(&"test_water"), "Last division can serve after finished conversation")
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE and session.shift.remaining == 0 and session.shift.get_events().size() == 2, "Reverse order reaches same two-event boundary")
	await _dispose(main)


func _test_time_boundary() -> void:
	var main := await _boot(1)
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	main.start_test_dialogue()
	await _focus(rig)
	_expect(not main.open_service_menu() and not session.open_service() and not session.can_open_service(), "Last division reserves ability to finish active dialogue")
	_expect(session.runner.active and session.mode == NarrativeSession.DIALOGUE and session.shift.remaining == 1 and not session.service.served, "Rejected service preserves active line and time")
	session.choose_for_node(&"test_guest_intro", &"opening", &"leave")
	session.finish_for_node(&"test_guest_intro", &"goodbye")
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE and session.shift.remaining == 0 and not session.runner.active, "Last dialogue reaches zero without a stranded runner")
	await _dispose(main)
	main = await _boot()
	rig = main.get_node("AnchorCamera")
	session = main.get_node("NarrativeSession")
	main.start_test_dialogue()
	await _focus(rig)
	main.open_service_menu()
	session.shift.apply_completed_event(&"test_external_action", 1)
	_expect(not session.serve_drink(&"test_water") and session.mode == NarrativeSession.SERVICE and session.runner.active and not session.service.served, "Serving repeats time check after menu opened")
	session.close_service()
	session.cancel_dialogue()
	_expect(main.open_service_menu() and session.serve_drink(&"test_water") and session.shift.remaining == 0, "Free cancellation releases final division for service")
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE and not session.runner.active, "Cancelled boundary has no stranded speech")
	await _dispose(main)
