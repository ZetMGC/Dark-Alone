extends SceneTree
## Снимки гостя и подачи через настоящий renderer; без --headless.

var _output: String
var _suffix: String = ""


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Service preview requires a rendering display driver")
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
	await _save("entry")
	rig.request_move(&"counter")
	await rig.anchor_reached
	await _save("guest")
	if not main.open_service_menu():
		quit(1)
		return
	await _save("menu")
	session.open_menu()
	await _save("pause")
	session.resume_menu()
	var drink_id := &"test_house_drink" if "--house" in OS.get_cmdline_user_args() else &"test_water"
	if not session.serve_drink(drink_id):
		quit(1)
		return
	await _save("served")
	main.start_test_dialogue()
	await _save("dialogue")
	session.cancel_dialogue()
	rig.request_move(&"entry")
	await rig.anchor_reached
	await _save("return")
	main.queue_free()
	await process_frame
	quit()


func _save(label: String) -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _output.path_join("da022_" + label + _suffix + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		printerr("Cannot save service preview: " + path)
		quit(1)
		return
	print("Saved service preview: " + path)
