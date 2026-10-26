extends SceneTree

var _output: String
var _suffix: String = ""


func _initialize() -> void:
	_capture.call_deferred()


func _settle(panel: JournalPanel) -> void:
	await process_frame
	while panel.is_transitioning():
		await process_frame
	await process_frame
	await process_frame


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	JournalPanel.motion_mode = &"full"
	_output = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(_output)
	var ignore := FileAccess.open(_output.path_join(".gdignore"), FileAccess.WRITE)
	ignore.close()
	if "--small" in OS.get_cmdline_user_args():
		_suffix = "_small"
		DisplayServer.window_set_size(Vector2i(960, 600))
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.free_roam_enabled = false
	root.add_child(main)
	current_scene = main
	var session := main.get_node("NarrativeSession") as NarrativeSession
	var panel := main.get_node("JournalPanel") as JournalPanel
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	rig.request_move(&"counter")
	await rig.anchor_reached
	main.start_test_dialogue()
	session.choose_for_node(&"test_guest_intro", &"opening", &"ask_more")
	session.open_journal()
	await _save("cover")
	await _settle(panel)
	await _save("open")
	session.bookmark_journal_entry(&"test_signal", true)
	await process_frame
	await _save("ribbon")
	panel.request_page(1)
	await create_timer(0.11).timeout
	await _save("turn")
	await _settle(panel)
	await _save("second_entry")
	session.open_menu()
	await _save("settings")
	session.resume_menu()
	session.request_close_journal()
	await create_timer(0.08).timeout
	await _save("closing")
	await _settle(panel)
	session.choose_for_node(&"test_guest_intro", &"explanation", &"finish")
	session.finish_for_node(&"test_guest_intro", &"goodbye")
	main.open_service_menu()
	session.serve_drink(&"test_water")
	session.go_home()
	session.finish_commute(session.commute.trip_id)
	session.open_journal()
	await _settle(panel)
	await _save("home")
	session.close_journal()
	var glossary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
	glossary.terms[0].description = "Длинная тестовая запись дневника для проверки страниц и русского текста. ".repeat(55)
	var dialogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	var catalog := DialogueCatalog.new()
	if not catalog.load_data(glossary, [dialogue]):
		quit(1)
		return
	var journal := Journal.new()
	journal.configure(catalog)
	journal.add_term(&"test_signal")
	journal.select_entry(&"test_signal")
	var stress := (load("res://scenes/ui/journal_panel.tscn") as PackedScene).instantiate() as JournalPanel
	root.add_child(stress)
	stress.reading_position_requested.connect(func(id: StringName, offset: int) -> void:
		journal.set_reading_offset(id, offset)
		stress.render(journal, false)
	)
	stress.render(journal, false)
	stress.set_open(true)
	await _settle(stress)
	await _save("long_page_1")
	stress.request_page(1)
	await _settle(stress)
	await _save("long_page_2")
	print("PASS: book opening, pages, leaf, closing, home and settings captured")
	quit()


func _save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := _output.path_join("da034_" + label + _suffix + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		printerr("FAIL: cannot save " + path)
		quit(1)
	print("Saved book preview: " + path)
