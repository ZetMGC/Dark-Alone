extends Node

var _checks: int = 0
var _failures: int = 0
var _catalog := DialogueCatalog.new()


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _fixture() -> Dictionary:
	var journal := Journal.new()
	journal.configure(_catalog)
	journal.add_term(&"test_signal", {"dialogue_id": "test_guest_intro", "node_id": "opening", "speaker": "[TEST] Гость", "shift": 1})
	journal.add_term(&"test_marker", {"dialogue_id": "test_guest_intro", "node_id": "explanation", "speaker": "[TEST] Гость", "shift": 1})
	journal.select_entry(&"test_signal")
	journal.set_bookmarked(&"test_signal", true)
	journal.set_reading_offset(&"test_signal", 5)
	var home := HomeState.new()
	home.observe(&"home_desk")
	home.observe(&"home_window")
	home.resolve_event(&"test_home_observation")
	return {"journal": journal, "home": home}


func _probe(mode: String, directory: String) -> void:
	if not directory.begins_with("user://checkpoint_tests/process_") or ".." in directory:
		_expect(false, "Probe directory restricted to test namespace")
	else:
		var store := CheckpointStore.new(directory)
		if mode == "write":
			var fixture := _fixture()
			_expect(not store.has_checkpoint(), "Fresh cross-process checkpoint namespace")
			_expect(store.save_checkpoint(2, fixture.journal, fixture.home, _catalog), "Write in first process")
		elif mode == "read":
			var result := store.load_checkpoint(_catalog)
			_expect(not result.is_empty() and result.shift == 2, "New process reads checkpoint")
			if not result.is_empty():
				_expect(result.journal.get_entry(&"test_signal").reading_offset == 5 and result.journal.get_entry(&"test_signal").bookmarked, "New process restores journal position/bookmark")
				_expect(result.home_state.has_resolved(&"test_home_observation"), "New process restores home event")
				var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
				main.free_roam_enabled = false
				main.checkpoint_store = store
				main.preferences_enabled = false
				get_tree().root.add_child(main)
				_expect(main.get_node("NarrativeSession").shift_number == 2 and main.get_node("HomeExploration").state.has_resolved(&"test_home_observation"), "New process boots the real game from disk")
				main.queue_free()
			_expect(store.clear_checkpoint() and not store.has_checkpoint(), "Cross-process fixture cleaned")
		else:
			_expect(false, "Known probe mode")
	print("%s: checkpoint probe %s, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", mode, _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	get_tree().create_timer(35).timeout.connect(func() -> void:
		printerr("FAIL: checkpoint test timeout")
		get_tree().quit(1)
	)
	_catalog.load_files("res://content/glossary/test_terms.json", ["res://content/dialogues/test_guest.json"])
	var probe := ""
	var directory := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--checkpoint-probe="):
			probe = arg.trim_prefix("--checkpoint-probe=")
		if arg.begins_with("--checkpoint-directory="):
			directory = arg.trim_prefix("--checkpoint-directory=")
	if not probe.is_empty():
		_probe(probe, directory)
		return
	_test_codec()
	_test_store()
	await _test_application()
	print("%s: shift checkpoint, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_codec() -> void:
	var fixture := _fixture()
	var codec := CheckpointCodec.new()
	var data := codec.encode(2, fixture.journal, fixture.home, _catalog)
	var restored := codec.decode(JSON.parse_string(JSON.stringify(data)), _catalog)
	_expect(not restored.is_empty(), "Version one JSON roundtrip")
	if restored.is_empty():
		return
	_expect(restored.journal.get_entries() == fixture.journal.get_entries(), "Order, sources and all journal flags preserved")
	_expect(restored.journal.selected_term_id == &"test_signal" and restored.journal.get_unread_count() == 1, "Restore selection does not mark unread entries read")
	_expect(restored.home_state.export_progress() == fixture.home.export_progress(), "Independent home progress restored")
	for mutation in ["version", "fractional_version", "hash", "shift", "future_source", "speaker", "node", "duplicate", "unknown_term", "read_type", "cursor", "fractional_cursor", "selection", "unknown_home", "duplicate_home", "event_requires"]:
		var bad := data.duplicate(true)
		match mutation:
			"version": bad.version = 99
			"fractional_version": bad.version = 1.5
			"hash": bad.content_hash = "outdated"
			"shift": bad.shift = 2.5
			"future_source": bad.journal.entries[0].source.shift = 2
			"speaker": bad.journal.entries[0].source.speaker = "unknown"
			"node": bad.journal.entries[0].source.node_id = "goodbye"
			"duplicate": bad.journal.entries.append(bad.journal.entries[0].duplicate(true))
			"unknown_term": bad.journal.entries[1].id = "unknown"
			"read_type": bad.journal.entries[0].read = "true"
			"cursor": bad.journal.entries[0].reading_offset = 999999
			"fractional_cursor": bad.journal.entries[0].reading_offset = 1.5
			"selection": bad.journal.selected = "unknown"
			"unknown_home": bad.home.observed.append("unknown")
			"duplicate_home": bad.home.observed.append("home_desk")
			"event_requires": bad.home.observed.clear()
		_expect(codec.decode(bad, _catalog).is_empty(), "Reject corrupted checkpoint: " + mutation)
	var empty := Journal.new()
	empty.configure(_catalog)
	var bad_journal: Dictionary = data.journal.duplicate(true)
	bad_journal.entries[1].id = "unknown"
	_expect(not empty.restore_progress(bad_journal) and empty.get_entries().is_empty(), "Invalid later entry cannot apply partial journal")
	_expect(not fixture.journal.restore_progress(data.journal), "Restore cannot overwrite a running journal")
	_expect(not fixture.home.restore_progress(data.home), "Restore cannot overwrite running home progress")
	var copy: Dictionary = fixture.journal.export_progress()
	copy.entries[0].source.speaker = "mutated"
	_expect(fixture.journal.get_entry(&"test_signal").source.speaker != "mutated", "Export is a deep copy")
	_expect(codec.encode(1, fixture.journal, fixture.home, _catalog).is_empty(), "Only subsequent shift starts can be saved")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _test_store() -> void:
	var directory := "user://checkpoint_tests/store_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store := CheckpointStore.new(directory)
	var fixture := _fixture()
	_expect(not store.has_checkpoint() and store.load_checkpoint(_catalog).is_empty(), "Missing file starts cleanly")
	_expect(store.save_checkpoint(2, fixture.journal, fixture.home, _catalog), "First checkpoint written")
	_expect(store.save_checkpoint(3, fixture.journal, fixture.home, _catalog), "Atomic replacement supported")
	_write(store.get_path() + ".tmp", "partial write")
	_expect(store.load_checkpoint(_catalog).shift == 3, "Incomplete temp file never loaded")
	_write(store.get_path(), "{corrupt")
	var recovered := store.load_checkpoint(_catalog)
	_expect(not recovered.is_empty() and recovered.shift == 2 and store.recovered_backup, "Corrupt primary recovers previous successful checkpoint")
	_expect(store.save_checkpoint(4, fixture.journal, fixture.home, _catalog), "New checkpoint repairs primary without copying corrupt backup")
	var before := FileAccess.get_file_as_string(store.get_path())
	DirAccess.make_dir_absolute(store.get_path() + ".bak.tmp")
	_expect(not store.save_checkpoint(5, fixture.journal, fixture.home, _catalog), "Backup IO failure is reported")
	_expect(FileAccess.get_file_as_string(store.get_path()) == before, "Failed write preserves previous primary")
	DirAccess.remove_absolute(store.get_path() + ".bak.tmp")
	_expect(store.clear_checkpoint() and not store.has_checkpoint(), "Explicit clear removes primary and backup")
	_write(store.get_path(), "x".repeat(CheckpointStore.MAX_BYTES + 1))
	_expect(store.load_checkpoint(_catalog).is_empty() and not store.last_error.is_empty(), "Oversized file rejected")
	_expect(FileAccess.file_exists(store.get_path()), "Bad save is not silently deleted on load")
	store.clear_checkpoint()
	_expect(not CheckpointStore.new("res://forbidden").save_checkpoint(2, fixture.journal, fixture.home, _catalog), "Writes restricted to user storage")


func _test_application() -> void:
	JournalPanel.motion_mode = &"off"
	var directory := "user://checkpoint_tests/application_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store := CheckpointStore.new(directory)
	var fixture := _fixture()
	store.save_checkpoint(2, fixture.journal, fixture.home, _catalog)
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := scene.instantiate()
	main.free_roam_enabled = false
	main.checkpoint_store = store
	main.preferences_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var rig: AnchorCamera = main.get_node("AnchorCamera")
	var home: HomeExploration = main.get_node("HomeExploration")
	_expect(session.shift_number == 2 and session.shift.remaining == 2 and not session.service.served and not session.runner.active, "Boot resumes fresh shift, never a half-completed action")
	_expect(session.journal.get_entry(&"test_signal").bookmarked and session.journal.get_entry(&"test_signal").reading_offset == 5 and home.state.has_resolved(&"test_home_observation"), "Boot restores journal and home")
	rig.fade_seconds = 0.01
	rig.black_hold_seconds = 0.0
	rig.request_move(&"counter")
	await rig.anchor_reached
	for repeat in 2:
		main.start_test_dialogue()
		session.choose_for_node(&"test_guest_intro", &"opening", &"leave")
		session.finish_for_node(&"test_guest_intro", &"goodbye")
		_expect(store.load_checkpoint(_catalog).shift == 2, "No save during work or at summary")
	session.journal.set_bookmarked(&"test_signal", false)
	session.go_home()
	session.finish_commute(session.commute.trip_id)
	home.rig.fade_seconds = 0.01
	home.rig.black_hold_seconds = 0.0
	home.rig.request_move(&"home_bed")
	await home.rig.anchor_reached
	home.rig.apply_look_delta(Vector2(0.7, -0.1))
	_expect(absf(home.rig.view.global_basis.x.y) < 0.00001, "Saved home flow retains level horizon from colleagues")
	home.inspect(&"home_bed")
	home.close_inspection(true)
	home.rig.request_move(&"home_entry")
	await home.rig.anchor_reached
	home.request_work()
	session.finish_commute(session.commute.trip_id)
	await get_tree().process_frame
	await get_tree().process_frame
	main = get_tree().current_scene
	session = main.get_node("NarrativeSession")
	var saved := CheckpointStore.new(directory).load_checkpoint(_catalog)
	_expect(session.shift_number == 3 and saved.shift == 3, "Successful ordinary reload writes start of next shift")
	_expect(saved.home_state.has_observed(&"home_bed") and not saved.journal.get_entry(&"test_signal").bookmarked, "Checkpoint captures completed home and latest journal flags")
	get_tree().current_scene = null
	main.queue_free()
	await get_tree().process_frame
	main = scene.instantiate()
	main.free_roam_enabled = false
	main.checkpoint_store = CheckpointStore.new(directory)
	main.preferences_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	session = main.get_node("NarrativeSession")
	_expect(session.shift_number == 3 and main.get_node("HomeExploration").state.has_observed(&"home_bed"), "New scene/store reconstructs state from disk")
	main.get_node("NavigationHUD").new_game_requested.emit()
	_expect(get_tree().current_scene == main and store.has_checkpoint(), "Stale new-game command outside menu rejected")
	session.open_menu()
	if DisplayServer.get_name() != "headless":
		var hud: NavigationHUD = main.get_node("NavigationHUD")
		hud.get_node("%NewGame").pressed.emit()
		_expect(hud.get_node("%ConfirmNewGame").visible, "New game requires visible confirmation")
		hud.get_node("%ConfirmNewGame").canceled.emit()
		hud.get_node("%ConfirmNewGame").hide()
		_expect(store.has_checkpoint() and session.shift_number == 3, "Cancelling new game preserves checkpoint")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir=") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var folder := argument.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(folder)
			_expect(get_viewport().get_texture().get_image().save_png(folder.path_join("da032_checkpoint_menu.png")) == OK, "Checkpoint menu screenshot")
	main.get_node("NavigationHUD").new_game_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	main = get_tree().current_scene
	session = main.get_node("NarrativeSession")
	_expect(session.shift_number == 1 and session.journal.get_entries().is_empty() and not store.has_checkpoint(), "Explicit new game clears disk and runtime together")
	_expect(main.get_node("HomeExploration").state.get_observed_ids().is_empty(), "New game resets home too")
	_write(store.get_path(), "{broken checkpoint")
	get_tree().current_scene = null
	main.queue_free()
	await get_tree().process_frame
	main = scene.instantiate()
	main.free_roam_enabled = false
	main.checkpoint_store = CheckpointStore.new(directory)
	main.preferences_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_expect(main.get_node("NarrativeSession").shift_number == 1 and FileAccess.file_exists(store.get_path()), "Corrupt boot starts safely and preserves invalid file")
	_expect("не загружено" in main.get_node("NavigationHUD/%CheckpointStatus").text, "Corrupt boot displays actionable status")
	store.clear_checkpoint()
	store.save_checkpoint(2, fixture.journal, fixture.home, _catalog)
	store.save_checkpoint(3, fixture.journal, fixture.home, _catalog)
	_write(store.get_path(), "{broken newer point")
	get_tree().current_scene = null
	main.queue_free()
	await get_tree().process_frame
	main = scene.instantiate()
	main.free_roam_enabled = false
	main.checkpoint_store = CheckpointStore.new(directory)
	main.preferences_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_expect(main.get_node("NarrativeSession").shift_number == 2 and "предыдущая" in main.get_node("NavigationHUD/%CheckpointStatus").text, "Actual boot falls back to previous checkpoint with status")
	main.checkpoint_store.clear_checkpoint()
	JournalPanel.motion_mode = &"full"
