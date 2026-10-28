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
	panel.set_ink_tool(index)


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
	_paper_model()
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
	await _paper_ui()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	JournalPanel.motion_mode = &"full"
	print("%s: journal ink, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _paper_model() -> void:
	var book := JournalNotebook.new()
	var a := book.add_note("[TEST] Вопрос", Vector2(0.2, 0.3))
	var b := book.add_note("[TEST] Наблюдение", Vector2(0.7, 0.5))
	_expect(a > 0 and b > a and book.link_notes(a, b), "Personal notes and directed link accepted")
	_expect(not book.link_notes(a, a) and not book.link_notes(a, b) and not book.link_notes(a, 99), "Self, duplicate and dangling links rejected")
	var other := book.add_note("Другая страница", Vector2(0.2, 0.3), 1)
	_expect(not book.link_notes(a, other), "Links cannot silently point into another spread")
	_expect(not book.move_note(a, Vector2(NAN, 0)) and not book.move_note(a, Vector2(-0.1, 0)), "Invalid coordinates rejected")
	_expect(not book.update_note(a, " ") and not book.update_note(a, "a".repeat(321)), "Empty and oversized notes rejected")
	var recipe := book.add_recipe("[TEST] Проба\n20 + 20\nРазмешать")
	_expect(recipe > other and book.update_recipe(recipe, "[TEST] Своя пропорция\n20 + 10"), "Recipe is editable personal text with independent ID")
	var snapshot := book.export_data()
	var clone := JournalNotebook.new()
	_expect(clone.restore_data(JSON.parse_string(JSON.stringify(snapshot))) and clone.export_data() == snapshot, "Notebook JSON roundtrip keeps coordinates, recipe and link")
	var invalid := snapshot.duplicate(true)
	invalid.links[0].to = 999
	_expect(not clone.restore_data(invalid) and clone.export_data() == snapshot, "Broken link rejects notebook atomically")
	invalid = snapshot.duplicate(true)
	invalid.notes[0].x = "0.2"
	_expect(not clone.restore_data(invalid) and clone.export_data() == snapshot, "String coordinate rejects atomically")
	invalid = snapshot.duplicate(true)
	invalid.recipes[0].id = a
	_expect(not clone.restore_data(invalid), "IDs cannot collide between notes and recipes")
	var copy := clone.get_notes(0)
	copy[0].text = "External mutation"
	_expect(clone.export_data() == snapshot, "Notebook getters return deep copies")
	_expect(clone.remove_note(a) and clone.get_links().is_empty(), "Deleting note removes its incident links")
	var journal := Journal.new()
	journal.configure(catalog)
	journal.notebook = book
	var restored := Journal.new()
	restored.configure(catalog)
	_expect(restored.restore_progress(JSON.parse_string(JSON.stringify(journal.export_progress()))), "Personal notebook restores even before any learned words")
	_expect(restored.notebook.export_data() == snapshot, "Journal progress includes exact notebook")
	var legacy := Journal.new()
	legacy.configure(catalog)
	_expect(legacy.restore_progress({"entries": [], "selected": ""}) and legacy.notebook.is_empty(), "Old checkpoint without notebook still reads")
	var store := CheckpointStore.new("user://checkpoint_tests/paper_" + str(Time.get_ticks_usec()))
	_expect(store.save_checkpoint(2, journal, HomeState.new(), catalog), "Personal notebook saved through real checkpoint Store")
	var loaded := store.load_checkpoint(catalog)
	_expect(not loaded.is_empty() and loaded.journal.notebook.export_data() == snapshot, "Disk checkpoint restores personal notes, recipes and arrows")
	_expect(store.clear_checkpoint(), "Personal checkpoint fixture cleaned")
	var cap := JournalNotebook.new()
	for index in 8:
		_expect(cap.add_note(str(index), Vector2(0.2, 0.3)) > 0, "Notes within spread capacity accepted")
	_expect(cap.add_note("overflow", Vector2(0.2, 0.3)) < 0, "Spread capacity bounded")


func _double_click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = true
	get_viewport().push_input(event, true)
	await _click(point, false)


func _paper_ui() -> void:
	JournalPanel.motion_mode = &"off"
	_expect(not panel.has_node("%Search") and not panel.has_node("%Section") and not panel.has_node("%InkTool"), "Application filters and dropdown toolbar removed from scene")
	var tab: Button = panel.get_node("%NotesTab")
	await _click(tab.get_global_rect().get_center(), true)
	await _click(tab.get_global_rect().get_center(), false)
	await _settle()
	var paper := panel.get_node("%PaperPages") as JournalPaperPages
	_expect(panel.current_section == &"notes" and paper.editing_enabled and not panel.get_node("%Card").visible, "Actual paper tab opens editable note spread")
	var position := Vector2(paper.size.x * 0.22, paper.size.y * 0.35)
	await _double_click(paper.global_position + position)
	var writer := paper.get_node("Writer") as TextEdit
	_expect(writer.visible and writer.has_focus(), "Double click on paper opens writing at selected position")
	writer.text = "[TEST] Что я заметил?\nПроверить после смены."
	await _key(KEY_ENTER, true)
	_expect(not writer.visible and session.journal.notebook.get_notes(0).size() == 1, "Ctrl+Enter leaves handwritten note in model")
	var second := Vector2(paper.size.x * 0.75, paper.size.y * 0.6)
	await _double_click(paper.global_position + second)
	writer.text = "[TEST] Другой вопрос\nМожет быть связано?"
	await _key(KEY_ENTER, true)
	var notes := session.journal.notebook.get_notes(0)
	var a := paper.global_position + paper.note_rect(notes[0]).get_center()
	var b := paper.global_position + paper.note_rect(notes[1]).get_center()
	var press := InputEventMouseButton.new()
	press.position = a
	press.global_position = a
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.shift_pressed = true
	get_viewport().push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = b
	motion.global_position = b
	get_viewport().push_input(motion, true)
	await _click(b, false)
	_expect(session.journal.notebook.get_links().size() == 1, "Real Shift drag connects notes with arrow")
	await _click(a, true)
	motion = InputEventMouseMotion.new()
	motion.position = a + Vector2(0, 30)
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)
	await _click(motion.position, false)
	_expect(session.journal.notebook.get_notes(0)[0].y > notes[0].y, "Real drag moves note without losing its text or links")
	a = paper.global_position + paper.note_rect(session.journal.notebook.get_notes(0)[0]).get_center()
	await _snap("05-personal-notes")
	await _double_click(a)
	writer.text = "Отменённая правка"
	await _key(KEY_ESCAPE)
	_expect(session.mode == NarrativeSession.JOURNAL and session.journal.notebook.get_notes(0)[0].text == notes[0].text, "Escape cancels edit without closing journal or changing note")
	_expect(panel.request_page(1) and paper.sheet == 1 and session.journal.notebook.get_notes(0).size() == 2, "Page corner turns to independent empty spread")
	_expect(not panel.get_node("%Previous").disabled, "Previous page corner updates after committing note spread turn")
	panel.request_page(-1)
	tab = panel.get_node("%RecipesTab")
	await _click(tab.get_global_rect().get_center(), true)
	await _click(tab.get_global_rect().get_center(), false)
	await _settle()
	_expect(panel.current_section == &"recipes" and paper.section == &"recipes", "Recipe tab opens personal recipe pages")
	await _double_click(paper.global_position + Vector2(paper.size.x * 0.75, 140))
	writer.text = "[TEST] Первая проба\n\nСостав\n20 мл плотного компонента\n20 мл лёгкого компонента\n\nКак готовил\nМягко налить второй по ложке.\n\nВ следующий раз\nСравнить с перемешанным вариантом."
	await _key(KEY_ENTER, true)
	_expect(session.journal.notebook.get_recipes().size() == 1, "Recipe page stores player's own proportions and method")
	await _snap("06-personal-recipe")
	_expect(not panel.get_node("%Next").disabled, "Long recipe exposes next page corner without a scrollbar")
	_expect(panel.request_page(1) and paper.recipe_page == 1, "Long recipe continues on next paper page")
	panel.request_page(-1)
	await _double_click(paper.global_position + Vector2(paper.size.x * 0.75, 140))
	writer.text = "x".repeat(4001)
	_expect(not paper.finish_edit() and writer.visible and not panel.select_section(&"notes") and not panel.begin_close(), "Oversized draft stays editable and blocks navigation/close rather than losing text")
	paper.finish_edit(true)
	var snapshot := session.journal.notebook.export_data()
	session.open_menu()
	_expect(not paper.editing_enabled, "Hidden journal cannot edit personal pages")
	session.resume_menu()
	await _settle()
	session.close_journal()
	session.open_journal()
	await _settle()
	_expect(session.journal.notebook.export_data() == snapshot and session.shift.remaining == 2, "Reopen keeps personal pages without time cost")
	panel.select_section(&"words")
	await _settle()
