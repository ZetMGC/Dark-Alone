extends Node

var _checks: int = 0
var _failures: int = 0
var _capture: String = ""
var catalog := DialogueCatalog.new()
var panel: JournalPanel
var session: NarrativeSession
var _store: CheckpointStore


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	for frame in 3:
		await get_tree().process_frame
	while panel.is_transitioning():
		await get_tree().process_frame
	await get_tree().process_frame


func _click(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	get_viewport().push_input(event, true)
	await get_tree().process_frame


func _key(code: Key, ctrl: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		get_viewport().push_input(event, true)
	await get_tree().process_frame


func _word_point(start: int, end: int) -> Vector2:
	var text: Control = panel.get_node("%Description")
	var rects: Array = text.range_rects(start, end)
	_expect(not rects.is_empty(), "Visible character range has glyph bounds")
	return text.get_global_transform_with_canvas() * rects[0].get_center() if not rects.is_empty() else text.global_position


func _tool(index: int) -> void:
	panel.get_node("%InkTool").select(index)
	panel.get_node("%InkTool").item_selected.emit(index)


func _snap(name: String) -> void:
	if _capture.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_expect(get_viewport().get_texture().get_image().save_png(_capture.path_join(name + ".png")) == OK, "Capture " + name)


func _model() -> void:
	var journal := Journal.new()
	journal.configure(catalog)
	_expect(not journal.add_annotation(&"test_signal", &"circle", 0, 6), "Unknown term cannot be annotated")
	journal.add_term(&"test_signal")
	_expect(not journal.add_annotation(&"test_signal", &"unknown", 0, 6) and not journal.add_annotation(&"test_signal", &"circle", -1, 6) and not journal.add_annotation(&"test_signal", &"circle", 6, 6) and not journal.add_annotation(&"test_signal", &"circle", 0, 999999), "Invalid mark kinds and ranges rejected")
	var nested: Array[bool] = []
	var reference: WeakRef = weakref(journal)
	journal.annotations_changed.connect(func(id: StringName) -> void: nested.append(reference.get_ref().add_annotation(id, &"circle", 7, 9)))
	_expect(journal.add_annotation(&"test_signal", &"underline", 0, 6) and nested == [false], "Atomic annotation signal blocks reentrant mutation")
	_expect(not journal.add_annotation(&"test_signal", &"underline", 0, 6), "Duplicate mark rejected")
	var copy := journal.get_annotations(&"test_signal")
	copy[0].start = 99
	_expect(journal.get_annotations(&"test_signal")[0].start == 0, "Getter is a deep copy")
	journal.add_annotation(&"test_signal", &"circle", 7, 9)
	_expect(journal.erase_annotation(&"test_signal", 0) and journal.get_annotations(&"test_signal").size() == 1, "Eraser removes chosen mark")
	_expect(journal.undo_annotations(&"test_signal") and journal.get_annotations(&"test_signal").size() == 2, "Undo restores erased mark")
	_expect(journal.undo_annotations(&"test_signal") and journal.get_annotations(&"test_signal").size() == 1 and journal.undo_annotations(&"test_signal", true), "Undo and redo creation")
	journal.undo_annotations(&"test_signal")
	journal.add_annotation(&"test_signal", &"circle", 10, 14)
	_expect(not journal.can_redo_annotations(&"test_signal"), "New action discards redo branch")
	var progress := journal.export_progress()
	var restored := Journal.new()
	restored.configure(catalog)
	_expect(restored.restore_progress(JSON.parse_string(JSON.stringify(progress))) and restored.get_annotations(&"test_signal") == journal.get_annotations(&"test_signal"), "JSON roundtrip restores semantic ranges")
	_expect(not restored.can_undo_annotations(&"test_signal"), "Undo history is not serialized")
	var old := progress.duplicate(true)
	old.erase("annotations")
	var legacy := Journal.new()
	legacy.configure(catalog)
	_expect(legacy.restore_progress(old) and legacy.get_annotations(&"test_signal").is_empty(), "Old journal progress remains compatible")
	for invalid in [{"unknown": []}, {"test_signal": [{"kind": "circle", "start": 0, "end": 999999}]}, {"test_signal": [{"kind": "circle", "start": 0.5, "end": 5}]}, {"test_signal": [{"kind": "circle", "start": 0, "end": 5, "extra": true}]}]:
		var bad := progress.duplicate(true)
		bad.annotations = invalid
		var target := Journal.new()
		target.configure(catalog)
		_expect(not target.restore_progress(bad) and target.get_entries().is_empty() and target.restore_progress(old), "Bad annotation rejects entire restore atomically")
	var cap := Journal.new()
	cap.configure(catalog)
	cap.add_term(&"test_signal")
	for index in Journal.MAX_ANNOTATIONS:
		_expect(cap.add_annotation(&"test_signal", &"underline", index, index + 1), "Bounded mark accepted")
	_expect(not cap.add_annotation(&"test_signal", &"circle", 0, 6), "Annotation capacity enforced")
	_store = CheckpointStore.new("user://checkpoint_tests/ink_" + str(Time.get_ticks_usec()))
	_expect(_store.save_checkpoint(2, journal, HomeState.new(), catalog), "Checkpoint writes annotations")
	var loaded := _store.load_checkpoint(catalog)
	_expect(not loaded.is_empty() and loaded.journal.get_annotations(&"test_signal") == journal.get_annotations(&"test_signal"), "New disk Store restores annotations")
	_expect(_store.clear_checkpoint(), "Test checkpoint cleaned")


func _run() -> void:
	get_tree().create_timer(40).timeout.connect(func() -> void:
		printerr("FAIL: ink test timeout")
		get_tree().quit(1)
	)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(_capture)
	get_window().size = Vector2i(1280, 720)
	if "--small" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(960, 600)
	var glossary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
	glossary.terms[0].title = "[TEST] Сигнал"
	glossary.terms[1].title = "[TEST] Метка"
	glossary.terms[0].description = "Сигнал за окном повторился. В дневнике осталось важное наблюдение: свет в комнате не менялся.\n\n".repeat(8)
	var dialogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	_expect(catalog.load_data(glossary, [dialogue]), "TEST catalog configured without changing authored content")
	_model()
	session = NarrativeSession.new()
	panel = (load("res://scenes/ui/journal_panel.tscn") as PackedScene).instantiate()
	var speech := (load("res://scenes/ui/dialogue_panel.tscn") as PackedScene).instantiate()
	var summary := (load("res://scenes/ui/shift_summary_panel.tscn") as PackedScene).instantiate()
	for node in [panel, speech, summary, session]:
		add_child(node)
	session.configure(catalog, speech, panel)
	session.configure_shift(2, summary)
	session.journal.add_term(&"test_signal")
	session.journal.add_term(&"test_marker")
	JournalPanel.motion_mode = &"off"
	session.open_journal()
	await _settle()
	var text: Control = panel.get_node("%Description")
	_expect(text.editing_enabled and panel.get_page_count() > 1, "Interactive handwriting is paginated")
	var point := _word_point(0, 6)
	await _click(point, true)
	await _click(point, false)
	_expect(text.selection == Vector2i(0, 6) and panel.get_node("%WordNote").text.contains("Сигнал"), "Actual mouse selects Cyrillic word and known meaning")
	_tool(1)
	_expect(session.journal.get_annotations(&"test_signal") == [{"kind": "underline", "start": 0, "end": 6}], "Toolbar underlines semantic word")
	_tool(0)
	point = _word_point(10, 15)
	await _click(point, true)
	await _click(point, false)
	_tool(2)
	_expect(session.journal.get_annotations(&"test_signal").size() == 2, "Circle tool encloses another word")
	_tool(0)
	await _click(_word_point(0, 6), true)
	var motion := InputEventMouseMotion.new()
	motion.position = _word_point(16, 26)
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)
	await _click(motion.position, false)
	_expect(text.selection.x == 0 and text.selection.y >= 25, "Drag selects a phrase across words")
	_tool(1)
	_expect(session.journal.get_annotations(&"test_signal").size() == 3, "Phrase can be underlined")
	_tool(0)
	await _snap("01-annotated-spread")
	_tool(3)
	point = _word_point(10, 15)
	await _click(point, true)
	await _click(point, false)
	_expect(session.journal.get_annotations(&"test_signal").size() == 2, "Eraser via real mouse deletes mark")
	await _key(KEY_Z, true)
	_expect(session.journal.get_annotations(&"test_signal").size() == 3, "Ctrl+Z restores erased mark")
	await _key(KEY_Y, true)
	_expect(session.journal.get_annotations(&"test_signal").size() == 2, "Ctrl+Y repeats erase")
	await _key(KEY_Z, true)
	_expect(session.journal.add_annotation(&"test_signal", &"circle", 28, 90), "Annotation can span wrapped lines")
	_expect(text.range_rects(28, 90).size() >= 2, "Wrapped phrase yields a separate contour per line")
	var saved := session.journal.get_annotations(&"test_signal")
	var initial_size := get_window().size
	get_window().size = Vector2i(1100, 680) if initial_size.x == 960 else Vector2i(960, 600)
	await _settle()
	_expect(session.journal.get_annotations(&"test_signal") == saved and not text.range_rects(0, 6).is_empty(), "Resize reshapes ink without modifying ranges")
	await _snap("02-resized")
	get_window().size = initial_size
	await get_tree().create_timer(0.12).timeout
	await _settle()
	JournalPanel.motion_mode = &"full"
	_expect(panel.request_page(1) and not text.editing_enabled, "Page turn blocks editing")
	text.annotation_requested.emit(&"circle", 1, 3)
	_expect(session.journal.get_annotations(&"test_signal") == saved, "Hidden transitioning page cannot change marks")
	await _settle()
	_expect(panel.request_page(-1), "Return to annotated page (index=%d count=%d offset=%d)" % [panel.get_page_index(), panel.get_page_count(), session.journal.get_entry(&"test_signal").reading_offset])
	await _settle()
	_expect(text.marks == saved and not text.range_rects(0, 6).is_empty(), "Annotations return on original text after leaf animation")
	await _snap("03-wrapped-annotations")
	_expect(session.select_journal_entry(&"test_marker"), "Select another entry through Session")
	text.annotation_requested.emit(&"circle", 0, 6)
	_expect(session.journal.get_annotations(&"test_marker").is_empty(), "Stale text before deferred pagination cannot annotate newly selected entry")
	await _settle()
	_expect(session.select_journal_entry(&"test_signal"), "Return to first entry")
	await _settle()
	_expect(text.marks == saved, "Entry changes keep annotation identity")
	session.open_menu()
	text.annotation_requested.emit(&"circle", 1, 3)
	_expect(not text.editing_enabled and session.journal.get_annotations(&"test_signal") == saved, "Menu hides and blocks ink")
	session.resume_menu()
	await _settle()
	await _snap("04-returned")
	session.close_journal()
	_expect(not text.editing_enabled and session.mode == NarrativeSession.EXPLORATION, "Close releases journal and blocks hidden input")
	session.open_journal()
	await _settle()
	_expect(text.marks == saved and session.shift.remaining == 2, "Reopen retains marks and spends no shift time")
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	JournalPanel.motion_mode = &"full"
	print("%s: journal ink, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
