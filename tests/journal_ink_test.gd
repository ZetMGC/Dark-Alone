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
	# Несколько разнесённых групп существуют только в этой TEST-fixture, не в каноне.
	for index in 4:
		glossary.terms.append({"id": "test_cluster_%d" % index, "title": "[TEST] " + ["Свет", "Шум", "Ритм", "Пауза"][index], "description": "Техническое слово для проверки размещения групп."})
	for index in 2:
		glossary.reasoning_groups.append({"id": "test_cluster_group_%d" % index, "title": "[TEST] Наблюдения %d" % (index + 1), "terms": ["test_cluster_%d" % (index * 2), "test_cluster_%d" % (index * 2 + 1)], "minimum_terms": 2, "sheet": 0, "position": [0.74, 0.26 + index * 0.44], "options": [{"id": "test_cluster_linked_%d" % index, "text": "[TEST] Сведения связаны."}, {"id": "test_cluster_separate_%d" % index, "text": "[TEST] Сведения не связаны."}]})
	glossary.reasoning_links = [{"from": "test_terms_connection", "to": "test_cluster_group_0", "required_conclusions": ["test_different_subjects"]}]
	var dialogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	_expect(catalog.load_data(glossary, [dialogue]), "TEST catalog configured without changing authored content")
	_model()
	_paper_model()
	_chain_model()
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
	_expect(not panel.are_pages_open() and panel.get_node("%Cover").visible and not panel.get_node("%Card").visible, "Default journal raises closed cover, hides all paper")
	_expect(not session.select_journal_entry(&"test_marker") and not panel.request_page(1), "Closed journal rejects reading and paging")
	var cover: Control = panel.get_node("%Cover")
	await _snap("closed-cover")
	await _click(cover.get_global_rect().get_center(), true)
	await _click(cover.get_global_rect().get_center(), false)
	await _settle()
	_expect(panel.are_pages_open() and not cover.visible, "Actual cover click reveals pages")
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
	session.open_journal(true)
	await _settle()
	_expect(text.marks == saved and session.shift.remaining == 2, "Reopen retains marks and spends no shift time")
	await _paper_ui()
	await _closed_book_ui()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	JournalPanel.motion_mode = &"full"
	print("%s: journal ink, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _paper_model() -> void:
	var journal := Journal.new()
	journal.configure(catalog)
	journal.add_term(&"test_signal")
	_expect(not journal.choose_conclusion(&"test_terms_connection", &"test_same_subject"), "Insufficient known words cannot yield a conclusion")
	var partial := journal.get_reasoning_groups(0)
	_expect(partial.size() == 1 and partial[0].terms == ["test_signal"] and partial[0].options.is_empty(), "Unknown words and premature options are not exposed")
	journal.add_term(&"test_marker")
	_expect(journal.get_reasoning_groups(0)[0].ready and journal.get_reasoning_groups(0)[0].options.size() == 3, "Enough words enable several authored conclusions")
	_expect(not journal.choose_conclusion(&"test_terms_connection", &"invented"), "Free-form conclusion ID rejected")
	_expect(journal.choose_conclusion(&"test_terms_connection", &"test_different_subjects"), "Alternative interpretation is a valid player conclusion")
	_expect(journal.has_conclusion(&"test_different_subjects") and not journal.has_conclusion(&"test_same_subject"), "Conclusion stores chosen interpretation, without declaring truth")
	_expect(journal.get_entries().size() == 2 and not journal.has_term(&"test_different_subjects"), "A conclusion does not become a discovered fact")
	_expect(not journal.choose_conclusion(&"test_terms_connection", &"test_same_subject"), "Committed conclusion cannot be silently rewritten")
	var snapshot := journal.export_progress()
	var clone := Journal.new()
	clone.configure(catalog)
	_expect(clone.restore_progress(JSON.parse_string(JSON.stringify(snapshot))) and clone.has_conclusion(&"test_different_subjects"), "Conclusions and evidence JSON roundtrip")
	var copy := clone.reasoning.export_data()
	copy[0].option_id = "changed"
	_expect(clone.has_conclusion(&"test_different_subjects"), "Conclusion getters are deep copies")
	for mutation in ["unknown_option", "unknown_evidence", "duplicate_evidence", "duplicate_group", "missing_evidence"]:
		var bad := snapshot.duplicate(true)
		match mutation:
			"unknown_option": bad.conclusions[0].option_id = "invented"
			"unknown_evidence": bad.conclusions[0].evidence[0] = "invented"
			"duplicate_evidence": bad.conclusions[0].evidence.append("test_signal")
			"duplicate_group": bad.conclusions.append(bad.conclusions[0].duplicate(true))
			"missing_evidence": bad.conclusions[0].evidence = ["test_signal"]
		var fresh := Journal.new()
		fresh.configure(catalog)
		_expect(not fresh.restore_progress(bad) and fresh.get_entries().is_empty() and fresh.reasoning.export_data().is_empty(), "Forged conclusions reject entire progress atomically: " + mutation)
	var visual := journal.make_visual_copy()
	_expect(visual.export_progress() == journal.export_progress(), "Page rendering copy preserves exact progress")
	visual.set_bookmarked(&"test_signal", true)
	_expect(not journal.get_entry(&"test_signal").bookmarked, "Page preview never mutates live knowledge")
	var linked := Journal.new()
	linked.configure(catalog)
	for id in [&"test_signal", &"test_marker", &"test_cluster_0", &"test_cluster_1"]:
		linked.add_term(id)
	_expect(linked.reasoning.get_links(0).is_empty(), "Knowledge alone does not draw relation arrows")
	linked.choose_conclusion(&"test_terms_connection", &"test_different_subjects")
	_expect(linked.reasoning.get_links(0).is_empty(), "One conclusion does not expose arrow")
	linked.choose_conclusion(&"test_cluster_group_0", &"test_cluster_linked_0")
	_expect(linked.reasoning.get_links(0).size() == 1, "Both matching conclusions derive declared arrow")
	var link_copy := Journal.new()
	link_copy.configure(catalog)
	_expect(link_copy.restore_progress(linked.export_progress()) and link_copy.reasoning.get_links(0).size() == 1, "Arrows derive again after restoring conclusions without new save fields")
	var wrong_version := Journal.new()
	wrong_version.configure(catalog)
	for id in [&"test_signal", &"test_marker", &"test_cluster_0", &"test_cluster_1"]:
		wrong_version.add_term(id)
	wrong_version.choose_conclusion(&"test_terms_connection", &"test_same_subject")
	wrong_version.choose_conclusion(&"test_cluster_group_0", &"test_cluster_linked_0")
	_expect(wrong_version.reasoning.get_links(0).is_empty(), "Optional version condition filters a relation without marking truth")
	_expect(not JournalReasoning.validate_links([{"from": "missing", "to": "test_cluster_group_0"}], catalog.get_reasoning_groups()), "Unknown linked group rejected")

	var store := CheckpointStore.new("user://checkpoint_tests/reasoning_" + str(Time.get_ticks_usec()))
	_expect(store.save_checkpoint(2, journal, HomeState.new(), catalog), "Real Store saves conclusions")
	var loaded := store.load_checkpoint(catalog)
	_expect(not loaded.is_empty() and loaded.journal.reasoning.export_data() == journal.reasoning.export_data(), "Disk checkpoint preserves interpretation and evidence")
	_expect(store.clear_checkpoint(), "Reasoning test store cleaned")
	var legacy := Journal.new()
	legacy.configure(catalog)
	_expect(legacy.restore_progress({"entries": [], "selected": ""}), "Old progress without conclusions still reads")
	var archive := Journal.new()
	archive.configure(catalog)
	var old_notebook := {"notes": [{"id": 1, "text": "[TEST] Старый личный текст", "x": 0.2, "y": 0.4, "sheet": 0, "circled": true}], "recipes": [], "links": []}
	var legacy_loaded := archive.restore_progress({"entries": [], "selected": "", "notebook": old_notebook})
	var archived_notes := archive.notebook.get_notes(0)
	_expect(legacy_loaded and archived_notes.size() == 1 and archived_notes[0].text == old_notebook.notes[0].text and is_equal_approx(archived_notes[0].x, 0.2), "DA-065 personal data retained as legacy archive without reintroducing typing UI")
	var modern := DialogueCatalog.new()
	modern.load_files("res://content/glossary/test_terms.json", ["res://content/dialogues/test_guest.json"])
	var old_glossary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
	old_glossary.erase("reasoning_groups")
	old_glossary.erase("journal_recipes")
	var before := DialogueCatalog.new()
	before.load_data(old_glossary, [JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))])
	_expect(CheckpointCodec.new().content_hash(modern) == CheckpointCodec.new().content_hash(before), "Adding optional reasoning groups preserves previous content hash and old save compatibility")
	var demo := DialogueCatalog.new()
	_expect(demo.load_files("res://content/glossary/test_terms.json", ["res://content/dialogues/test_reasoning_guest.json"]), "Authored TEST conclusion dialogue is validated")
	for option in [&"test_same_subject", &"test_different_subjects"]:
		var knowledge := Journal.new()
		knowledge.configure(demo)
		var runner := DialogueRunner.new()
		runner.configure(demo, knowledge)
		runner.start(&"test_reasoning_guest_intro")
		runner.choose(&"ask_more")
		_expect(not runner.choose(&"use_same_conclusion") and not runner.choose(&"use_different_conclusion"), "Words alone do not unlock conclusion answers")
		knowledge.choose_conclusion(&"test_terms_connection", option)
		var choice := &"use_same_conclusion" if option == &"test_same_subject" else &"use_different_conclusion"
		var other := &"use_different_conclusion" if option == &"test_same_subject" else &"use_same_conclusion"
		_expect(not runner.choose(other) and runner.choose(choice), "Only selected conclusion unlocks its NPC answer")
		_expect(runner.current_node_id == (&"test_same_response" if option == &"test_same_subject" else &"test_different_response"), "Interpretations lead to different actual dialogue branches")
	var invalid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
	invalid.reasoning_groups[0].terms.append("invented")
	_expect(not DialogueCatalog.new().load_data(invalid, [JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))]), "Invalid authored evidence reference rejected before catalog changes")


func _click_group_point(paper: JournalPaperPages, group: Dictionary) -> void:
	var point := paper.global_position + paper.get_conclusion_button_rect(group).get_center()
	await _click(point, true)
	await _click(point, false)


func _paper_ui() -> void:
	JournalPanel.motion_mode = &"off"
	for index in 4:
		session.journal.add_term(StringName("test_cluster_%d" % index))
	_expect(not panel.has_node("%Search") and not panel.has_node("%Section"), "Application filters stay removed")
	var tab: Button = panel.get_node("%NotesTab")
	await _click(tab.get_global_rect().get_center(), true)
	await _click(tab.get_global_rect().get_center(), false)
	await _settle()
	var paper := panel.get_node("%PaperPages") as JournalPaperPages
	_expect(panel.current_section == &"notes" and paper.editing_enabled and not paper.has_node("Writer"), "Real tab opens discovered words without any text editor")
	var group: Dictionary = session.journal.get_reasoning_groups(0)[0]
	_expect(session.journal.get_reasoning_groups(0).size() == 3, "Several authored word groups occupy separate areas of the spread")
	_expect(group.ready and group.conclusion.is_empty(), "Enough words automatically form a circled group with a conclusion point")
	var word_point := paper.global_position + paper.get_word_rects(group)[0].get_center()
	await _click(word_point, true)
	var drag := InputEventMouseMotion.new()
	drag.position = word_point + Vector2(80, 30)
	drag.global_position = drag.position
	get_viewport().push_input(drag, true)
	await _click(drag.position, false)
	_expect(paper.get_pending_group() == &"", "Dragging over words no longer draws or opens a conclusion")
	await _click_group_point(paper, group)
	_expect(paper.get_pending_group() == &"test_terms_connection", "Actual click on small point opens conclusion choices")
	var option_bounds := Rect2(Vector2.ZERO, paper.size)
	for index in group.options.size():
		_expect(option_bounds.encloses(paper.get_option_rect(index)), "Popup choice fits paper at current window size")
	_expect(paper.get_option_rect(-1).size == Vector2.ZERO and paper.get_option_rect(group.options.size()).size == Vector2.ZERO, "No phantom row outside actual choices")
	await _key(KEY_1)
	_expect(paper.get_pending_group() == &"test_terms_connection" and not session.journal.has_conclusion(&"test_same_subject"), "Number keys do not accidentally commit mouse-only popup")
	var outside := paper.global_position + Vector2(12, paper.size.y - 55)
	await _click(outside, true)
	await _click(outside, false)
	_expect(paper.get_pending_group() == &"" and session.mode == NarrativeSession.JOURNAL, "Outside click dismisses popup without closing book or choosing")
	await _click_group_point(paper, group)
	await _snap("05-conclusion-options")
	session.open_menu()
	_expect(not paper.choose_option(0), "Hidden journal rejects stale conclusion choice")
	session.resume_menu()
	await _settle()
	await _key(KEY_ESCAPE)
	_expect(paper.get_pending_group() == &"" and session.mode == NarrativeSession.JOURNAL, "Escape after menu cancels pending interpretation before closing book")
	await _click_group_point(paper, group)
	var choice := paper.global_position + paper.get_option_rect(1).get_center()
	await _click(choice, true)
	await _click(choice, false)
	_expect(session.journal.has_conclusion(&"test_different_subjects"), "Actual click writes chosen interpretation without free text")
	_expect(not paper.choose_option(0), "Stale option cannot replace committed conclusion")
	_expect(paper.get_visible_links().is_empty(), "Arrow stays hidden while related target has no conclusion")
	var related: Dictionary = session.journal.get_reasoning_groups(0)[1]
	await _click_group_point(paper, related)
	for index in related.options.size():
		_expect(Rect2(Vector2.ZERO, paper.size).encloses(paper.get_option_rect(index)), "Right-side popup flips inside spread")
	await _snap("05b-right-conclusion-options")
	var related_choice := paper.global_position + paper.get_option_rect(0).get_center()
	await _click(related_choice, true)
	await _click(related_choice, false)
	_expect(paper.get_visible_links().size() == 1 and not paper.open_conclusion(StringName(related.id)), "Declared arrow appears only after both conclusions, committed point cannot reopen")
	await _snap("06-recorded-conclusion")
	tab = panel.get_node("%RecipesTab")
	await _click(tab.get_global_rect().get_center(), true)
	await _click(tab.get_global_rect().get_center(), false)
	await _settle()
	_expect(panel.current_section == &"recipes" and not session.journal.get_journal_recipes().is_empty() and paper.get_child_count() == 0, "Recipes are authored read-only pages without typing or adding")
	_expect(not paper.open_conclusion(&"test_cluster_group_1"), "A stale point command cannot open conclusions on recipe pages")
	await _snap("07-readonly-recipe")
	session.close_journal()
	session.open_journal(true)
	await _settle()
	_expect(session.journal.has_conclusion(&"test_different_subjects") and session.shift.remaining == 2, "Reopen preserves conclusion without costing shift time")
	panel.select_section(&"notes")
	await _settle()
	JournalPanel.motion_mode = &"full"
	panel.request_page(1)
	await get_tree().create_timer(0.16).timeout
	_expect(panel.is_transitioning() and panel.get_node("%Leaf").turn_amount > 0, "Curved paper leaf animates before committing page")
	if DisplayServer.get_name() != "headless":
		_expect(panel.get_node("%Leaf").turn_texture != null and panel.get_node("%Leaf").target_texture != null, "GPU turn uses two exact rendered page snapshots")
	var target_image: Image
	if DisplayServer.get_name() != "headless" and panel.get_node("%Leaf").target_texture != null:
		target_image = panel.get_node("%Leaf").target_texture.get_image()
	await _snap("08-curved-page")
	session.open_menu()
	var paused: float = panel.get_node("%Leaf").turn_amount
	await get_tree().create_timer(0.1).timeout
	_expect(is_equal_approx(paused, panel.get_node("%Leaf").turn_amount), "New curved animation pauses in menu")
	session.resume_menu()
	await _settle()
	_expect(paper.sheet == 1, "Page turn commits once after resume")
	if target_image != null:
		await RenderingServer.frame_post_draw
		var live := get_viewport().get_texture().get_image()
		var mismatch := _page_mismatch(target_image, live)
		_expect(mismatch < 0.005, "Page image stays identical when frozen target hands off to live UI (mismatch %.4f)" % mismatch)
	panel.request_page(-1)
	await _settle()
	panel.select_section(&"words")
	await _settle()
	JournalPanel.motion_mode = &"full"
	session.close_journal()
	session.open_journal(true)
	await get_tree().create_timer(0.14).timeout
	_expect(panel.is_transitioning() and panel.get_node("%Card").modulate.a == 1.0 and panel.get_node("%PaperPages").modulate.a == 1.0, "Opening moves intact pages without threshold text opacity")
	await _settle()
	if DisplayServer.get_name() != "headless":
		panel.request_page(1)
		while panel.is_transitioning() and panel.get_node("%Leaf").target_texture == null:
			await get_tree().process_frame
		var word_target: Image = panel.get_node("%Leaf").target_texture.get_image()
		await _settle()
		await RenderingServer.frame_post_draw
		var mismatch := _page_mismatch(word_target, get_viewport().get_texture().get_image())
		print("Dictionary page handoff mismatch: %.6f" % mismatch)
		_expect(mismatch < 0.005, "Actual word page preserves glyph positions, source and annotations at handoff")


func _page_mismatch(target: Image, live: Image) -> float:
	var bad := 0
	var total := 0
	for y in range(int(live.get_height() * 0.14), int(live.get_height() * 0.75), 3):
		for x in range(int(live.get_width() * 0.12), int(live.get_width() * 0.88), 3):
			var a := target.get_pixel(x, y)
			var b := live.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.12:
				bad += 1
			total += 1
	return float(bad) / maxi(1, total)


func _chain_model() -> void:
	var demo := DialogueCatalog.new()
	_expect(demo.load_files("res://content/glossary/test_war_cinema_terms.json", ["res://content/dialogues/test_war_cinema_guest.json"]), "Fictional TEST bundle validates")
	for path in [["test_veteran", "test_hidden_arms", "arms", "arms_reply"], ["test_cinema", "test_props", "props", "props_reply"], ["test_veteran", "test_keepsakes", "keepsakes", "keepsakes_reply"], ["test_cinema", "test_set", "set", "set_reply"]]:
		var journal := Journal.new()
		journal.configure(demo)
		var runner := DialogueRunner.new()
		runner.configure(demo, journal)
		_expect(runner.start(&"test_war_cinema_guest") and journal.get_known_term_ids().size() == 2, "Conversation first reveals war and battle words")
		_expect(runner.choose(&"more") and journal.get_known_term_ids().size() == 4, "Second line reveals weapon and crate words")
		_expect(not runner.choose(StringName(path[2])) and not journal.choose_conclusion(&"test_arsenal", StringName(path[1])), "Dialogue and dependent deduction locked before premise")
		_expect(journal.get_reasoning_groups(0)[1].words_ready and not journal.get_reasoning_groups(0)[1].ready, "Enough words circle target without premature choices")
		_expect(journal.choose_conclusion(&"test_memories", StringName(path[0])), "First interpretation accepted")
		var target: Dictionary = journal.get_reasoning_groups(0)[1]
		_expect(target.ready and target.options.size() == 2 and journal.reasoning.get_links(0, journal.get_known_term_ids()).size() == 1, "Source interpretation draws circle-to-circle arrow and unlocks two matching deductions")
		var opposite := &"test_props" if path[0] == "test_veteran" else &"test_hidden_arms"
		_expect(not journal.choose_conclusion(&"test_arsenal", opposite), "Opposite premise cannot be bypassed through API")
		_expect(journal.choose_conclusion(&"test_arsenal", StringName(path[1])), "Matching second interpretation accepted")
		var saved := journal.export_progress()
		_expect(saved.conclusions[1].premises == [path[0]], "Dependent deduction records its premise")
		saved.conclusions.reverse()
		var restored := Journal.new()
		restored.configure(demo)
		_expect(restored.restore_progress(JSON.parse_string(JSON.stringify(saved))) and restored.has_conclusion(StringName(path[1])), "Dependent deductions restore atomically in either order")
		var forged := saved.duplicate(true)
		forged.conclusions[0].premises = []
		_expect(not restored.restore_progress(forged) and restored.has_conclusion(StringName(path[1])), "Forged premise rejected without changing previous progress")
		_expect(runner.choose(StringName(path[2])) and runner.current_node_id == StringName(path[3]), "Chosen deduction opens corresponding fictional NPC response")
	var groups := demo.get_reasoning_groups()
	groups[0].options[0]["required_conclusions"] = ["test_hidden_arms"]
	_expect(not JournalReasoning.validate_groups(groups, demo.get_term_ids()), "Cyclic deduction dependencies rejected")
	groups = demo.get_reasoning_groups()
	groups[1].options[0].required_conclusions = ["unknown"]
	_expect(not JournalReasoning.validate_groups(groups, demo.get_term_ids()), "Unknown prerequisite rejected")


func _closed_book_ui() -> void:
	for mode in [&"full", &"reduced", &"off"]:
		session.close_journal()
		JournalPanel.motion_mode = mode
		_expect(session.open_journal(), "Closed-book entry accepted: " + str(mode))
		await _settle()
		_expect(not panel.are_pages_open() and not panel.get_node("%PaperPages").visible, "Lift finishes with pages still hidden: " + str(mode))
		_expect(panel.open_cover() and not panel.open_cover(), "Only one cover opening can run: " + str(mode))
		var target: Image
		if mode == &"full":
			await get_tree().create_timer(0.13).timeout
			session.open_menu()
			var progress: float = panel.get_node("%Leaf").turn_amount
			await get_tree().create_timer(0.07).timeout
			_expect(is_equal_approx(progress, panel.get_node("%Leaf").turn_amount), "Cover opening pauses while menu hides book")
			session.resume_menu()
			if DisplayServer.get_name() != "headless":
				while panel.is_transitioning() and panel.get_node("%Leaf").target_texture == null:
					await get_tree().process_frame
				_expect(panel.get_node("%Leaf").target_texture != null, "Cover unfolds into actual rendered target pages")
				target = panel.get_node("%Leaf").target_texture.get_image()
		await _settle()
		_expect(panel.are_pages_open() and not panel.get_node("%Cover").visible and not panel.is_transitioning(), "Cover settles into interactive pages: " + str(mode))
		if target != null:
			await RenderingServer.frame_post_draw
			var mismatch := _page_mismatch(target, get_viewport().get_texture().get_image())
			print("Cover handoff mismatch: %.6f" % mismatch)
			_expect(mismatch < 0.005, "Cover target hands off without page/glyph flash")
