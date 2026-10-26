extends SceneTree

var _output: String
var _suffix: String = ""


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
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
	root.add_child(main)
	current_scene = main
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var session := main.get_node("NarrativeSession") as NarrativeSession
	await _save("entry")
	rig.request_move(&"counter")
	await rig.anchor_reached
	await _save("bartender")
	main.open_service_menu()
	await _save("service")
	session.serve_drink(&"test_water")
	await _save("served")
	main.start_test_dialogue()
	session.choose_for_node(&"test_guest_intro", &"opening", &"leave")
	session.finish_for_node(&"test_guest_intro", &"goodbye")
	await _save("summary")
	session.open_journal()
	await _save("journal")
	session.close_journal()
	main.restart_shift()
	await process_frame
	await process_frame
	await _save("new_shift")
	quit()


func _save(label: String) -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _output.path_join("da023_" + label + _suffix + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		quit(1)
		return
	print("Saved shift preview: " + path)
