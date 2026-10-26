extends SceneTree
## Реальный renderer, обычный и минимальный размер. Результаты — artifacts/.

var _output: String
var _suffix: String = ""


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	JournalPanel.motion_mode = &"off"
	if DisplayServer.get_name() == "headless":
		printerr("Narrative preview requires a rendering display driver")
		quit(1)
		return
	_output = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(_output)
	var ignore := FileAccess.open(_output.path_join(".gdignore"), FileAccess.WRITE)
	if ignore == null:
		quit(1)
		return
	ignore.close()
	if "--small" in OS.get_cmdline_user_args():
		DisplayServer.window_set_size(Vector2i(960, 600))
		_suffix = "_small"
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	root.add_child(main)
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var session := main.get_node("NarrativeSession") as NarrativeSession
	session.open_journal()
	await _save("empty_journal")
	session.close_journal()
	rig.request_move(&"counter")
	await rig.anchor_reached
	await _save("counter")
	main.start_test_dialogue()
	await _save("dialogue")
	session.choose_for_node(&"test_guest_intro", &"opening", &"ask_more")
	session.open_journal()
	await _save("journal")
	session.open_menu()
	await _save("menu")
	session.resume_menu()
	session.close_journal()
	session.choose_for_node(&"test_guest_intro", &"explanation", &"finish")
	await _save("terminal")
	session.finish_for_node(&"test_guest_intro", &"goodbye")
	main.queue_free()
	await process_frame
	# Стресс-просмотр длинной реплики и переноса многострочного ответа.
	var catalog := DialogueCatalog.new()
	var glossary: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	pack.dialogues[0].nodes[0].text = "[TEST] Длинная реплика для проверки прокрутки. ".repeat(70)
	pack.dialogues[0].nodes[0].choices[0].text = "[TEST] Длинный ответ с переносом строк: ".repeat(8)
	if not catalog.load_data(glossary, [pack]):
		quit(1)
		return
	var panel := (load("res://scenes/ui/dialogue_panel.tscn") as PackedScene).instantiate() as DialoguePanel
	root.add_child(panel)
	var journal := Journal.new()
	var runner := DialogueRunner.new()
	journal.configure(catalog)
	runner.configure(catalog, journal)
	runner.start(&"test_guest_intro")
	panel.render(runner, journal)
	panel.set_open(true)
	await _save("long_text")
	var scroll := panel.get_node("%Scroll") as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _save("long_choices")
	panel.queue_free()
	await process_frame
	quit()


func _save(label: String) -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _output.path_join("da021_" + label + _suffix + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		printerr("Cannot save narrative preview: " + path)
		quit(1)
		return
	print("Saved narrative preview: " + path)
