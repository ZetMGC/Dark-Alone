extends SceneTree

var _output: String
var _suffix: String = ""


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	JournalPanel.motion_mode = &"off"
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	_output = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(_output)
	var ignore := FileAccess.open(_output.path_join(".gdignore"), FileAccess.WRITE)
	ignore.close()
	if "--small" in OS.get_cmdline_user_args():
		_suffix = "_small"
		DisplayServer.window_set_size(Vector2i(960, 600))
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	main.free_roam_enabled = false
	root.add_child(main)
	current_scene = main
	var session := main.get_node("NarrativeSession") as NarrativeSession
	session.open_journal()
	await _save("empty")
	session.close_journal()
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	rig.request_move(&"counter")
	await rig.anchor_reached
	main.start_test_dialogue()
	session.choose_for_node(&"test_guest_intro", &"opening", &"ask_more")
	session.open_journal()
	await _save("index")
	var panel := main.get_node("JournalPanel") as JournalPanel
	panel.select_section(&"notes")
	await _save("notes")
	panel.select_section(&"recipes")
	await _save("recipes")
	panel.select_section(&"words")
	session.select_journal_entry(&"test_marker")
	session.bookmark_journal_entry(&"test_marker", true)
	await _save("bookmarks")
	session.close_journal()
	session.choose_for_node(&"test_guest_intro", &"explanation", &"finish")
	session.finish_for_node(&"test_guest_intro", &"goodbye")
	main.open_service_menu()
	session.serve_drink(&"test_water")
	session.go_home()
	session.finish_commute(session.commute.trip_id)
	session.go_to_work()
	session.finish_commute(session.commute.trip_id)
	await process_frame
	await process_frame
	var fresh := current_scene
	fresh.get_node("NarrativeSession").open_journal()
	await _save("retained")
	fresh.get_node("NarrativeSession").close_journal()
	# Стресс-данные только в памяти, исходные пакеты не меняются.
	var glossary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
	for index in 24:
		glossary.terms.append({"id": "test_extra_%d" % index, "title": "[TEST] Длинная запись номер %d" % index, "description": "Длинная тестовая запись для проверки прокрутки и чтения. ".repeat(50)})
	var dialogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	var catalog := DialogueCatalog.new()
	if not catalog.load_data(glossary, [dialogue]):
		quit(1)
		return
	var journal := Journal.new()
	journal.configure(catalog)
	for index in 24:
		journal.add_term(StringName("test_extra_%d" % index))
	journal.select_entry(&"test_extra_0")
	var stress := (load("res://scenes/ui/journal_panel.tscn") as PackedScene).instantiate() as JournalPanel
	root.add_child(stress)
	stress.render(journal, false)
	stress.set_open(true)
	await _save("long")
	print("PASS: journal core previews saved")
	quit()


func _save(label: String) -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _output.path_join("da033_" + label + _suffix + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		printerr("FAIL: cannot save " + path)
		quit(1)
	print("Saved journal preview: " + path)
