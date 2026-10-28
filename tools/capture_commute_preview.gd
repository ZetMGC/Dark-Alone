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
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var session := main.get_node("NarrativeSession") as NarrativeSession
	var panel := main.get_node("CommutePanel") as CommutePanel
	rig.request_move(&"counter")
	await rig.anchor_reached
	for repeat in 2:
		main.start_test_dialogue()
		session.choose_for_node(&"test_guest_intro", &"opening", &"leave")
		session.finish_for_node(&"test_guest_intro", &"goodbye")
	await _save("summary")
	session.go_home()
	await create_timer(0.6).timeout
	await _save("to_home")
	session.open_menu()
	await _save("pause")
	session.resume_menu()
	panel.get_node("%Skip").pressed.emit()
	await _save("home")
	session.open_journal(true)
	await _save("home_journal")
	session.close_journal()
	session.go_to_work()
	await create_timer(0.6).timeout
	await _save("to_work")
	panel.get_node("%Skip").pressed.emit()
	await process_frame
	await process_frame
	await _save("new_shift")
	print("PASS: commute screenshots saved")
	quit()


func _save(label: String) -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _output.path_join("da031_" + label + _suffix + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		printerr("FAIL: cannot save " + path)
		quit(1)
	print("Saved commute preview: " + path)
