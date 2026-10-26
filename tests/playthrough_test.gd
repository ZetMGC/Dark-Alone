extends Node
## Сквозной проход настоящего Main через ввод и кнопки, включая новую смену.

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait_book()


func _move(code: Key, target: StringName) -> void:
	await _key(code)
	await get_tree().create_timer(0.8).timeout
	_expect(get_tree().current_scene.get_node("AnchorCamera").current_anchor_id == target, "Keyboard route: " + str(target))


func _press(panel: String, button: String) -> void:
	var control := get_tree().current_scene.get_node(panel).get_node(button) as Button
	_expect(control.is_visible_in_tree() and not control.disabled, "Available button: " + panel + "/" + button)
	control.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait_book()


func _wait_book() -> void:
	while get_tree().current_scene != null and get_tree().current_scene.has_node("JournalPanel"):
		var main := get_tree().current_scene
		if main.get_node("NarrativeSession").mode != NarrativeSession.JOURNAL or not main.get_node("JournalPanel").is_transitioning():
			return
		await get_tree().process_frame


func _run() -> void:
	if "--checkpoint-check" in OS.get_cmdline_user_args():
		get_tree().root.add_child((load("res://tests/checkpoint_test.tscn") as PackedScene).instantiate())
		return
	if "--faces-check" in OS.get_cmdline_user_args():
		get_tree().root.add_child((load("res://tests/faces_test.tscn") as PackedScene).instantiate())
		return
	if "--image-detail-check" in OS.get_cmdline_user_args():
		get_tree().root.add_child((load("res://tests/image_detail_test.tscn") as PackedScene).instantiate())
		return
	if "--display-check" in OS.get_cmdline_user_args():
		get_tree().root.add_child((load("res://tests/display_test.tscn") as PackedScene).instantiate())
		return
	if "--book-check" in OS.get_cmdline_user_args():
		get_tree().root.add_child((load("res://tests/book_test.tscn") as PackedScene).instantiate())
		return
	get_tree().create_timer(30).timeout.connect(func() -> void:
		printerr("FAIL: playthrough timed out")
		get_tree().quit(1)
	)
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	for long_branch: bool in [true, false]:
		var session := get_tree().current_scene.get_node("NarrativeSession") as NarrativeSession
		_expect(session.shift.remaining == 2 and session.journal.get_entries().size() == (0 if long_branch else 2), "Fresh clock and retained knowledge after ordinary return")
		await _move(KEY_2, &"counter")
		await _move(KEY_3, &"table")
		await _move(KEY_4, &"corner")
		await _move(KEY_1, &"entry")
		await _move(KEY_2, &"counter")
		await _key(KEY_B)
		await _key(KEY_ESCAPE)
		await _key(KEY_T)
		await _press("DialoguePanel", "%Cancel")
		_expect(session.shift.remaining == 2, "Cancelled actions do not consume time")
		if not long_branch:
			await _serve(1)
		await _key(KEY_T)
		await _key(KEY_J)
		await _key(KEY_ESCAPE)
		_expect(session.mode == NarrativeSession.DIALOGUE and session.runner.current_node_id == &"opening", "Journal returns to same line")
		var choices := get_tree().current_scene.get_node("DialoguePanel/%Choices")
		(choices.get_child(0 if long_branch else 1) as Button).pressed.emit()
		await get_tree().process_frame
		_expect(session.runner.current_node_id == (&"explanation" if long_branch else &"goodbye"), "Choice changes narrative branch")
		if long_branch:
			await _key(KEY_ESCAPE)
			await _key(KEY_ESCAPE)
			await _press("DialoguePanel", "%Choices/" + str(choices.get_child(0).name))
		await _press("DialoguePanel", "%Finish")
		_expect(session.journal.get_entries().size() == 2, "Long branch learned and next shift does not duplicate knowledge")
		if long_branch:
			await _serve(0)
		_expect(session.shift.finished and session.mode == NarrativeSession.SHIFT_COMPLETE and session.shift.get_events().size() == 2, "Full cycle ends once at zero")
		_expect(session.service.selected_drink_id == (&"test_water" if long_branch else &"test_house_drink"), "Chosen drink retained in summary")
		await _capture_summary(long_branch)
		await _key(KEY_1)
		_expect(get_tree().current_scene.get_node("AnchorCamera").current_anchor_id == &"counter", "Ended shift blocks movement")
		await _press("ShiftSummaryPanel", "%Journal")
		await _key(KEY_ESCAPE)
		if long_branch:
			await _press("ShiftSummaryPanel", "%GoHome")
			_expect(session.mode == NarrativeSession.TRAVEL, "Export starts home trip")
			await _key(KEY_ESCAPE)
			await _key(KEY_ESCAPE)
			await _press("CommutePanel", "%Skip")
			_expect(session.mode == NarrativeSession.HOME, "Export arrives home")
			await _press("HomeExploration", "%Journal")
			await _key(KEY_ESCAPE)
			_expect(session.mode == NarrativeSession.HOME, "Export diary returns home")
			await _press("HomeExploration", "%Work")
			await _press("CommutePanel", "%Skip")
		else:
			await _press("ShiftSummaryPanel", "%Restart")
		await get_tree().process_frame
		_expect(get_tree().current_scene.get_node("AnchorCamera").current_anchor_id == &"entry", "New shift reloads entry")
		_expect(get_tree().current_scene.get_node("NarrativeSession").journal.get_entries().size() == (2 if long_branch else 0), "Ordinary return retains knowledge while explicit test reset clears it")
	print("%s: full playthrough, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _serve(option_index: int) -> void:
	await _key(KEY_B)
	await _press("ServicePanel", "%Menu")
	await _key(KEY_ESCAPE)
	var options := get_tree().current_scene.get_node("ServicePanel/%Options")
	var button := options.get_child(1 + option_index * 3) as Button
	_expect(button.is_visible_in_tree() and not button.disabled, "Drink option visible after pause")
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame


func _capture_summary(long_branch: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--capture-dir="):
			continue
		var directory := argument.trim_prefix("--capture-dir=")
		DirAccess.make_dir_recursive_absolute(directory)
		await RenderingServer.frame_post_draw
		var path := directory.path_join("da024_summary_" + ("long" if long_branch else "short") + ".png")
		_expect(get_viewport().get_texture().get_image().save_png(path) == OK, "Export screenshot written")
