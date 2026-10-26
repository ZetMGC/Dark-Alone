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


func _catalog(extra: bool = false) -> DialogueCatalog:
	var catalog := DialogueCatalog.new()
	var glossary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
	var dialogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	if extra:
		for index in 30:
			glossary.terms.append({"id": "test_extra_%d" % index, "title": "[TEST] Дополнительная запись %d" % index, "description": "Длинное описание. ".repeat(50)})
	_expect(catalog.load_data(glossary, [dialogue]), "Accepted content fixture")
	return catalog


func _run() -> void:
	create_timer(20).timeout.connect(func() -> void:
		printerr("FAIL: journal core timed out")
		quit(1)
	)
	_test_model()
	await _test_shifts_and_ui()
	print("%s: journal core, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_model() -> void:
	var catalog := _catalog()
	var journal := Journal.new()
	_expect(not journal.add_term(&"test_signal") and not journal.select_entry(&"test_signal"), "Unknown entries rejected before configuration")
	_expect(journal.configure(catalog) and journal.matches_catalog(_catalog()), "Compatible immutable definitions")
	var changed_catalog := _catalog(true)
	_expect(not journal.matches_catalog(changed_catalog), "Changed dictionary cannot silently replace definitions")
	_expect(not journal.add_term(&"unknown") and not journal.set_bookmarked(&"unknown", true), "Unknown IDs cannot create entries")
	for source: Dictionary in [{"speaker": "only"}, {"dialogue_id": "test", "node_id": "opening", "speaker": "Guest", "shift": 0}, {"dialogue_id": "test", "node_id": "opening", "speaker": "Guest", "shift": 1, "extra": true}]:
		_expect(not journal.add_term(&"test_signal", source), "Malformed context rejected atomically")
	var source := {"dialogue_id": "test_guest_intro", "node_id": "opening", "speaker": "[TEST] Гость", "shift": 1}
	var nested: Array[bool] = []
	var journal_ref: WeakRef = weakref(journal)
	journal.term_added.connect(func(_id: StringName) -> void: nested.append(journal_ref.get_ref().add_term(&"test_marker")))
	_expect(journal.add_term(&"test_signal", source), "First entry accepted")
	source.speaker = "MUTATED"
	_expect(journal.get_entry(&"test_signal").source.speaker == "[TEST] Гость" and not nested.has(true), "Source copied and nested add blocked")
	_expect(journal.get_unread_count() == 1 and journal.selected_term_id == &"test_signal", "New entries unread, stable initial selection")
	_expect(journal.select_entry(&"test_signal") and journal.get_unread_count() == 0, "Explicit selection marks read")
	_expect(journal.set_bookmarked(&"test_signal", true) and not journal.set_bookmarked(&"test_signal", true), "Bookmark idempotent")
	_expect(not journal.add_term(&"test_signal") and journal.get_entry(&"test_signal").bookmarked, "Duplicate does not reset metadata")
	_expect(journal.add_term(&"test_marker"), "Legacy one-argument add remains valid")
	_expect(journal.get_entry(&"test_marker").source.is_empty(), "Missing context remains explicit")
	_expect(journal.get_filtered_entries("пЕРВЫЙ").size() == 1 and journal.get_filtered_entries("несуществующее").is_empty(), "Cyrillic case insensitive search")
	_expect(journal.get_filtered_entries("", &"new").size() == 1 and journal.get_filtered_entries("", &"bookmarks").size() == 1, "New and bookmark sections")
	_expect(journal.get_filtered_entries("", &"bad").is_empty(), "Unknown section returns no data")
	var entries := journal.get_entries()
	entries[0].source.shift = 99
	entries[0].read = false
	_expect(journal.get_entry(&"test_signal").source.shift == 1 and journal.get_entry(&"test_signal").read, "Deep entry copies protect state")
	_expect(journal.get_entry(&"test_signal").entry_id == "term:test_signal" and journal.get_entry(&"test_marker").learned_order == 2, "Entry IDs and acquisition order stable")
	_expect(not journal.get_definition(&"test_signal").has("read"), "Definitions remain separate from progress")
	var many := Journal.new()
	many.configure(_catalog(true))
	for index in 30:
		many.add_term(StringName("test_extra_%d" % index))
	_expect(many.get_entries().size() == 30 and many.get_unread_count() == 30, "Many long entries do not need pages as IDs")
	var session := NarrativeSession.new()
	var dialogue_panel := (load("res://scenes/ui/dialogue_panel.tscn") as PackedScene).instantiate() as DialoguePanel
	var journal_panel := (load("res://scenes/ui/journal_panel.tscn") as PackedScene).instantiate() as JournalPanel
	var service_panel := (load("res://scenes/ui/service_panel.tscn") as PackedScene).instantiate() as ServicePanel
	for node in [dialogue_panel, journal_panel, service_panel, session]:
		root.add_child(node)
	var drinks: Array[Dictionary] = [{"id": "test_water", "title": "[TEST] Вода", "description": "Тест."}]
	_expect(not session.configure(changed_catalog, dialogue_panel, journal_panel, service_panel, &"test_guest", drinks, journal) and not session.service.is_configured(), "Incompatible shared journal rejected before mutating service")
	_expect(session.configure(catalog, dialogue_panel, journal_panel, service_panel, &"test_guest", drinks, journal), "Valid configuration can follow rejected dictionary")
	for node in [dialogue_panel, journal_panel, service_panel, session]:
		node.queue_free()


func _test_shifts_and_ui() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var remembered: Journal
	for number in [1, 2]:
		var session := main.get_node("NarrativeSession") as NarrativeSession
		var panel := main.get_node("JournalPanel") as JournalPanel
		var rig := main.get_node("AnchorCamera") as AnchorCamera
		rig.fade_seconds = 0.02
		rig.black_hold_seconds = 0.0
		rig.request_move(&"counter")
		await rig.anchor_reached
		main.start_test_dialogue()
		if number == 2:
			session.choose_for_node(&"test_guest_intro", &"opening", &"ask_more")
			session.choose_for_node(&"test_guest_intro", &"explanation", &"finish")
		else:
			session.choose_for_node(&"test_guest_intro", &"opening", &"leave")
		session.open_journal()
		_expect(session.journal.get_unread_count() == (0 if number == 1 else 1), "Only shown entry becomes read")
		if number == 2:
			panel.get_node("%Next").pressed.emit()
			_expect(session.journal.selected_term_id == &"test_marker" and session.journal.get_unread_count() == 0, "Next selects and reads another entry")
		panel.get_node("%Bookmark").button_pressed = true
		_expect(session.journal.get_entry(session.journal.selected_term_id).bookmarked, "Bookmark UI changes selected record")
		_expect(not session.bookmark_journal_entry(&"unknown", true), "Stale/unknown bookmark command rejected")
		panel.get_node("%Search").text = "несуществующее"
		panel.get_node("%Search").text_changed.emit("несуществующее")
		_expect(panel.get_node("%Index").item_count == 0, "Search filters index without changing selected record")
		panel.get_node("%Search").text = ""
		panel.get_node("%Search").text_changed.emit("")
		panel.get_node("%Section").select(2)
		panel.get_node("%Section").item_selected.emit(2)
		_expect(panel.get_node("%Index").item_count == number, "Bookmark filter reflects retained bookmarks")
		panel.get_node("%Search").grab_focus()
		for code: Key in [KEY_J, KEY_T, KEY_B]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			event.keycode = code
			event.unicode = code + 32
			event.pressed = true
			root.push_input(event)
		_expect(session.mode == NarrativeSession.JOURNAL and panel.get_node("%Search").text == "jtb", "Typing search cannot trigger game shortcuts")
		_expect(session.shift.remaining == 2 and session.runner.current_node_id == &"goodbye", "Reading/search/bookmarks preserve time and dialogue")
		session.close_journal()
		session.finish_for_node(&"test_guest_intro", &"goodbye")
		main.open_service_menu()
		session.serve_drink(&"test_water")
		remembered = session.journal
		_expect(session.journal.get_entry(&"test_signal").source.shift == 1, "Duplicate learning preserves first shift")
		session.go_home()
		session.finish_commute(session.commute.trip_id)
		session.go_to_work()
		session.finish_commute(session.commute.trip_id)
		await process_frame
		await process_frame
		main = current_scene
		var next := main.get_node("NarrativeSession") as NarrativeSession
		_expect(next.journal == remembered and next.shift_number == number + 1 and next.journal.get_entries().size() == number, "Ordinary shift retains exact journal, bumps shift and keeps terms")
		_expect(next.shift.remaining == 2 and not next.service.served and not has_meta(&"dark_alone_journal_handoff"), "Transient models reset and handoff consumed")
	var final_session := main.get_node("NarrativeSession") as NarrativeSession
	_expect(final_session.journal.get_entry(&"test_marker").source.shift == 2 and final_session.journal.selected_term_id == &"test_marker", "Second source and last selected entry survive two returns")
	main.queue_free()
	await process_frame
