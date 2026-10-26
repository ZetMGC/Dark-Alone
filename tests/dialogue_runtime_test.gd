extends SceneTree
## Модели исполнения и модальная интеграция настоящей сцены.

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _catalog(document: Dictionary = {}) -> DialogueCatalog:
	var catalog := DialogueCatalog.new()
	if document.is_empty():
		_expect(catalog.load_files("res://content/glossary/test_terms.json", PackedStringArray(["res://content/dialogues/test_guest.json"])), "Load fixture")
	else:
		var glossary: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
		_expect(catalog.load_data(glossary, [document]), "Load modified valid fixture")
	return catalog


func _run() -> void:
	JournalPanel.motion_mode = &"off"
	create_timer(20).timeout.connect(func() -> void:
		printerr("FAIL: runtime test timed out")
		quit(1)
	)
	_test_models()
	_test_conditions_cycles_and_snapshots()
	await _test_disabled_ui()
	await _test_scene()
	await process_frame
	print("%s: dialogue runtime, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_models() -> void:
	var catalog := _catalog()
	var journal := Journal.new()
	var runner := DialogueRunner.new()
	_expect(not runner.start(&"test_guest_intro"), "Unconfigured runner rejects start")
	_expect(not journal.add_term(&"test_signal"), "Unconfigured journal rejects grant")
	_expect(journal.configure(catalog) and runner.configure(catalog, journal), "Configure session models")
	_expect(not journal.configure(catalog) and not runner.configure(catalog, journal), "No implicit session reset")
	var added: PackedStringArray = []
	var finished: PackedStringArray = []
	var cancelled: PackedStringArray = []
	journal.term_added.connect(func(id: StringName) -> void: added.append(str(id)))
	runner.dialogue_finished.connect(func(id: StringName) -> void: finished.append(str(id)))
	runner.dialogue_cancelled.connect(func(id: StringName) -> void: cancelled.append(str(id)))
	var runner_ref: WeakRef = weakref(runner)
	var reentrant: Array[bool] = []
	journal.term_added.connect(func(_id: StringName) -> void: reentrant.append(runner_ref.get_ref().cancel()))
	runner.node_changed.connect(func(_a: StringName, _b: StringName) -> void: reentrant.append(runner_ref.get_ref().choose(&"leave")))
	_expect(not runner.start(&"missing") and not runner.active, "Unknown dialogue is a no-op")
	_expect(runner.start(&"test_guest_intro"), "Start fixture")
	_expect(runner.current_node_id == &"opening" and journal.has_term(&"test_signal"), "Entry effects before choices")
	_expect(not runner.start(&"test_guest_intro"), "No concurrent conversation")
	_expect(not runner.finish() and not runner.choose(&"missing"), "Invalid commands preserve non-terminal node")
	_expect(runner.choose(&"leave") and runner.is_terminal(), "Short branch reaches final text")
	_expect(finished.is_empty() and runner.active, "Final text waits for explicit finish")
	_expect(runner.finish() and not runner.finish(), "Finish accepted once")
	_expect(finished.size() == 1 and journal.get_entries().size() == 1, "Short branch grants one term")
	_expect(runner.start(&"test_guest_intro") and runner.choose(&"ask_more"), "Replay can take long branch")
	_expect(journal.get_known_term_ids() == PackedStringArray(["test_signal", "test_marker"]), "Acquisition order and no duplicates")
	_expect(runner.choose(&"finish") and runner.finish(), "Long branch completes")
	_expect(added.size() == 2 and finished.size() == 2, "Replay does not repeat grants")
	_expect(runner.start(&"test_guest_intro") and runner.cancel(), "Cancel active dialogue")
	_expect(not runner.cancel() and cancelled.size() == 1 and finished.size() == 2, "Cancel does not emit finish")
	_expect(journal.get_entries().size() == 2, "Cancel preserves acquired terms")
	_expect(not journal.add_term(&"missing") and not journal.add_term(&"test_signal"), "Unknown and duplicate journal grants rejected")
	_expect(added.size() == 2, "Rejected grants emit no event")
	var entries := journal.get_entries()
	entries[0].description = "MUTATED"
	var ids := journal.get_known_term_ids()
	ids.clear()
	_expect(journal.get_entries()[0].description != "MUTATED" and journal.get_entries().size() == 2, "Journal getters return copies")
	_expect(not reentrant.is_empty() and not reentrant.has(true), "Callbacks cannot re-enter runner mutations")


func _test_conditions_cycles_and_snapshots() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	document.dialogues[0].nodes[0].choices[0].required_terms = ["test_marker"]
	var catalog := _catalog(document)
	var journal := Journal.new()
	var runner := DialogueRunner.new()
	journal.configure(catalog)
	runner.configure(catalog, journal)
	runner.start(&"test_guest_intro")
	_expect(not runner.get_choices()[0].available and runner.get_choices()[0].missing_terms == PackedStringArray(["test_marker"]), "Missing terms disable choice")
	_expect(not runner.choose(&"ask_more") and runner.current_node_id == &"opening", "Condition checked at execution")
	journal.add_term(&"test_marker")
	_expect(runner.get_choices()[0].available and runner.choose(&"ask_more"), "Newly known term unlocks choice")
	var copy := runner.get_current_node()
	copy.text = "MUTATED"
	var choices := runner.get_choices()
	choices[0].target = "missing"
	_expect(runner.get_current_node().text != "MUTATED" and runner.choose(&"finish"), "Runner views cannot mutate execution")
	runner.finish()
	document = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	document.dialogues[0].allow_cycles = true
	document.dialogues[0].cycle_note = "[TEST] Возврат к началу, выход через leave."
	document.dialogues[0].nodes[1].choices[0].target = "opening"
	catalog = _catalog(document)
	journal = Journal.new()
	runner = DialogueRunner.new()
	journal.configure(catalog)
	runner.configure(catalog, journal)
	var grants: PackedStringArray = []
	journal.term_added.connect(func(id: StringName) -> void: grants.append(str(id)))
	runner.start(&"test_guest_intro")
	for loop in 3:
		_expect(runner.choose(&"ask_more") and runner.choose(&"finish"), "Intentional cycle returns to opening")
		for read in 4:
			runner.get_current_node()
			runner.get_choices()
	_expect(grants.size() == 2, "Cycles and reads do not repeat effects")
	document.dialogues[0].id = "replacement"
	var glossary: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
	_expect(catalog.load_data(glossary, [document]), "Reload source catalog")
	_expect(runner.choose(&"leave") and runner.finish(), "Existing runner survives catalog reload")
	_expect(not runner.start(&"replacement") and runner.start(&"test_guest_intro"), "Session uses frozen definitions")
	runner.cancel()


func _key(key: Key) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = key
	press.keycode = key
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.physical_keycode = key
	release.keycode = key
	Input.parse_input_event(release)


func _test_disabled_ui() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	document.dialogues[0].nodes[0].choices[0].required_terms = ["test_marker"]
	var panel := (load("res://scenes/ui/dialogue_panel.tscn") as PackedScene).instantiate() as DialoguePanel
	var journal_panel := (load("res://scenes/ui/journal_panel.tscn") as PackedScene).instantiate() as JournalPanel
	var session := NarrativeSession.new()
	root.add_child(panel)
	root.add_child(journal_panel)
	root.add_child(session)
	_expect(session.configure(_catalog(document), panel, journal_panel), "Configure conditional UI")
	session.start_dialogue(&"test_guest_intro")
	var button := panel.get_node("%Choices").get_child(0) as Button
	_expect(button.disabled, "Unavailable choice rendered disabled")
	button.pressed.emit()
	_expect(session.runner.current_node_id == &"opening", "Even forged disabled button event is rejected")
	session.journal.add_term(&"test_marker")
	button = panel.get_node("%Choices").get_child(0)
	_expect(not button.disabled, "New term refreshes choice availability")
	button.pressed.emit()
	_expect(session.runner.current_node_id == &"explanation", "Unlocked rendered choice executes")
	panel.queue_free()
	journal_panel.queue_free()
	session.queue_free()
	await process_frame


func _test_scene() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	root.add_child(main)
	await process_frame
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var session := main.get_node("NarrativeSession") as NarrativeSession
	var interaction := main.get_node("InteractionController") as InteractionController
	var panel := main.get_node("DialoguePanel") as DialoguePanel
	var journal_panel := main.get_node("JournalPanel") as JournalPanel
	var hud := main.get_node("NavigationHUD") as NavigationHUD
	rig.fade_seconds = 0.02
	rig.black_hold_seconds = 0.02
	_expect(not main.start_test_dialogue(), "World entry cannot open counter dialogue")
	_key(KEY_J)
	await process_frame
	_expect(session.mode == NarrativeSession.JOURNAL and journal_panel.screen.visible, "J opens empty journal")
	_expect(not rig.request_move(&"counter") and not interaction.activate(rig.get_anchor(&"counter")), "Journal blocks navigation and interactions")
	var view_before := rig.view.rotation
	rig.apply_look_delta(Vector2.ONE)
	_expect(rig.view.rotation == view_before, "Journal blocks look")
	_key(KEY_ESCAPE)
	await process_frame
	_expect(session.mode == NarrativeSession.EXPLORATION, "Escape closes journal")
	hud.destination_requested.emit(&"counter")
	_key(KEY_J)
	_expect(session.mode == NarrativeSession.EXPLORATION, "Journal cannot open during fade")
	if rig.is_transitioning:
		await rig.anchor_reached
	await physics_frame
	await physics_frame
	await process_frame
	var query := PhysicsRayQueryParameters3D.create(rig.view.global_position, rig.view.global_position - rig.view.global_basis.z * 15, 3)
	query.collide_with_areas = true
	var ray_hit := rig.get_world_3d().direct_space_state.intersect_ray(query)
	_expect(ray_hit.get("collider") == main.get_node("DialogueTrigger"), "Counter ray points at test trigger")
	if ray_hit.get("collider") != main.get_node("DialogueTrigger"):
		print("Ray diagnostic: ", rig.view.global_position, " direction ", -rig.view.global_basis.z, " hit ", ray_hit)
	_key(KEY_E)
	await process_frame
	_expect(session.mode == NarrativeSession.DIALOGUE and panel.screen.visible, "Conversation panel visible")
	if session.mode != NarrativeSession.DIALOGUE:
		main.queue_free()
		await process_frame
		return
	_expect(session.runner.current_node_id == &"opening" and session.journal.get_entries().size() == 1, "Scene applies first entry effect")
	_expect(not rig.request_move(&"table"), "Dialogue blocks direct camera request")
	hud.destination_requested.emit(&"table")
	_key(KEY_3)
	_expect(not rig.is_transitioning, "Dialogue blocks HUD and shortcut navigation")
	var old_button := panel.get_node("%Choices").get_child(0) as Button
	var stale_command: Callable = old_button.pressed.get_connections()[0].callable
	_key(KEY_TAB)
	await process_frame
	_expect(root.gui_get_focus_owner() == old_button, "Tab focuses first answer")
	_key(KEY_ENTER)
	await process_frame
	_expect(session.runner.current_node_id == &"explanation" and session.journal.get_entries().size() == 2, "Rendered choice takes long branch")
	stale_command.call()
	_expect(session.runner.current_node_id == &"explanation", "Stale node button is rejected")
	_key(KEY_J)
	await process_frame
	_expect(session.mode == NarrativeSession.JOURNAL and not panel.screen.visible and journal_panel.screen.visible, "Journal overlays conversation")
	_expect(not session.choose_for_node(&"test_guest_intro", &"explanation", &"finish"), "Hidden conversation commands rejected")
	session.open_menu()
	await process_frame
	_expect(session.mode == NarrativeSession.MENU and not journal_panel.screen.visible and hud.get_node("%Menu").visible, "Menu overlays journal")
	_key(KEY_ESCAPE)
	await process_frame
	_expect(session.mode == NarrativeSession.JOURNAL and journal_panel.screen.visible, "Menu resumes journal")
	_key(KEY_ESCAPE)
	await process_frame
	_expect(session.mode == NarrativeSession.DIALOGUE and session.runner.current_node_id == &"explanation", "Journal resumes exact node")
	_key(KEY_ESCAPE)
	await process_frame
	_expect(session.mode == NarrativeSession.MENU and not session.choose_for_node(&"test_guest_intro", &"explanation", &"finish"), "Menu blocks choice")
	_key(KEY_ESCAPE)
	await process_frame
	_expect(session.mode == NarrativeSession.DIALOGUE, "Escape resumes conversation")
	panel.get_node("%Choices").get_child(0).pressed.emit()
	_expect(session.runner.is_terminal() and panel.get_node("%Finish").visible, "Final text requires explicit close")
	var finishes: PackedStringArray = []
	session.runner.dialogue_finished.connect(func(id: StringName) -> void: finishes.append(str(id)))
	panel.get_node("%Finish").pressed.emit()
	panel.get_node("%Finish").pressed.emit()
	_expect(session.mode == NarrativeSession.EXPLORATION and finishes.size() == 1, "Finish once restores exploration")
	_key(KEY_T)
	await process_frame
	_expect(session.mode == NarrativeSession.DIALOGUE and session.journal.get_entries().size() == 2, "T replays without duplicate terms")
	panel.get_node("%Cancel").pressed.emit()
	_expect(session.mode == NarrativeSession.EXPLORATION and finishes.size() == 1, "Cancel has no finish event")
	_expect(rig.can_move_to(&"table"), "Navigation restored after cancel")
	main.queue_free()
	await process_frame
