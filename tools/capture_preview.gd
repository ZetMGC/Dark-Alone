extends SceneTree
## Запуск с обычным renderer, не --headless. Снимки пишутся в artifacts/.


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Preview capture requires a rendering display driver")
		quit(1)
		return
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	root.add_child(main)
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var output := ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(output)
	var ignore := FileAccess.open(output.path_join(".gdignore"), FileAccess.WRITE)
	if ignore == null:
		printerr("Cannot mark preview directory as ignored by Godot")
		quit(1)
		return
	ignore.close()
	for destination: StringName in [&"entry", &"counter", &"table", &"corner"]:
		if destination != rig.current_anchor_id:
			if not rig.request_move(destination):
				printerr("Cannot reach preview destination: " + str(destination))
				quit(1)
				return
			await rig.anchor_reached
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := output.path_join("m1_" + str(destination) + ".png")
		var result := root.get_texture().get_image().save_png(path)
		if result != OK:
			printerr("Cannot save preview: " + path)
			quit(1)
			return
		print("Saved preview: " + path)
	main.queue_free()
	await process_frame
	quit()
