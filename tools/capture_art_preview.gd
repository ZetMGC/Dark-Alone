extends SceneTree

var _output: String
var _suffix: String = ""


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	JournalPanel.motion_mode = &"off"
	if DisplayServer.get_name() == "headless":
		printerr("Art capture requires a rendering display driver")
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
	root.add_child(main)
	current_scene = main
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var presentation := main.get_node("Presentation") as PresentationController
	var session := main.get_node("NarrativeSession") as NarrativeSession
	for destination: StringName in [&"entry", &"counter", &"table", &"corner"]:
		if destination != rig.current_anchor_id:
			rig.request_move(destination)
			await rig.anchor_reached
		await _save(str(destination))
		if destination == &"counter":
			presentation.set_retro_enabled(false)
			await _save("counter_clean")
			presentation.set_retro_enabled(true)
			# Медленный обзор в обе стороны, без автоматической тряски.
			for direction in [-1.0, 1.0]:
				for frame in 30:
					rig.apply_look_delta(Vector2(direction * 0.006, 0))
					await process_frame
				await _save("look_left" if direction < 0 else "look_center")
			rig.reset_look()
			session.open_menu()
			await _save("settings")
			session.resume_menu()
			main.start_test_dialogue()
			await _save("dialogue")
			session.open_journal()
			await _save("journal")
			session.close_journal()
			session.cancel_dialogue()
	print("PASS: art anchors, settings, dialogue, journal, look and fades captured")
	quit()


func _save(label: String) -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _output.path_join("da030_" + label + _suffix + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		printerr("FAIL: cannot save " + path)
		quit(1)
	print("Saved art preview: " + path)
