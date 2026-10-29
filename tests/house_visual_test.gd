extends Node
## Снимок исходной геометрии и ракурсы до/после. Baseline записывается только явно.

const BASELINE := "res://tests/fixtures/house_layout_baseline.json"
var failures := 0

func _stable_path(path: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("@([A-Za-z0-9]+)@[0-9]+")
	return pattern.sub(path, "$1", true)

func _ready() -> void:
	_run.call_deferred()

func _snapshot(root: Node) -> Dictionary:
	var result := {}
	for node in root.find_children("*", "Node3D", true, false):
		if not (node is MeshInstance3D or node is CollisionShape3D or node is AnchorPoint):
			continue
		var entry := {"transform": var_to_str(node.transform)}
		if node is CollisionShape3D:
			entry["shape"] = var_to_str(node.shape.size) if node.shape is BoxShape3D else node.shape.get_class()
			entry["layer"] = node.get_parent().collision_layer
		if node is MeshInstance3D and node.mesh != null:
			entry["bounds"] = var_to_str(node.mesh.get_aabb())
		result[_stable_path(str(root.get_path_to(node)))] = entry
	return result

func _run() -> void:
	get_tree().create_timer(45).timeout.connect(func(): get_tree().quit(1))
	var main = load("res://scenes/main/reasoning_demo.tscn").instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	if "--no-retro" in OS.get_cmdline_user_args():
		main.get_node("Presentation").set_retro_enabled(false)
	var home = main.get_node("HomeExploration")
	var session = main.get_node("NarrativeSession")
	# Прямой контекст допустим только для визуального fixture; игровые переходы проверяет house_layout.
	session.mode = NarrativeSession.HOME
	home.set_context(NarrativeSession.HOME)
	await get_tree().process_frame
	var snapshot := _snapshot(home)
	if "--record-baseline" in OS.get_cmdline_user_args():
		if FileAccess.file_exists(BASELINE):
			printerr("Refusing to replace the original house baseline")
			get_tree().quit(1)
			return
		DirAccess.make_dir_recursive_absolute("res://tests/fixtures")
		FileAccess.open(BASELINE, FileAccess.WRITE).store_string(JSON.stringify(snapshot, "\t"))
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		for old_path in expected:
			var path := _stable_path(old_path)
			if path.begins_with("AnchorCamera/"): continue
			if not snapshot.has(path):
				printerr("FAIL: original house node missing: " + path)
				failures += 1
				continue
			for key in expected[old_path]:
				var actual = snapshot[path][key]
				var original = expected[old_path][key]
				var equal: bool = actual == original
				if key in ["bounds", "transform"]:
					equal = str_to_var(actual).is_equal_approx(str_to_var(original))
				if key == "layer": equal = int(actual) == int(original)
				if not equal:
					printerr("FAIL: original house geometry changed: " + path + " / " + key)
					failures += 1
		print("House preserved: %d original meshes, shapes and anchors; %d differences" % [expected.size(), failures])
		var dressing: Node3D = home.house.get_node("VisualDressing")
		if not dressing.find_children("*", "CollisionObject3D", true, false).is_empty():
			printerr("FAIL: visual dressing introduces physical obstacles")
			failures += 1
		# Размер и положение ткани следуют исходным интерактивным шторам.
		var curtain: MeshInstance3D = home.house.get_node("LivingCurtain")
		var cloth: MeshInstance3D = dressing.get_node("LivingCurtainFabric")
		var old_size: Vector3 = curtain.mesh.size
		var old_position: Vector3 = curtain.position
		curtain.mesh.size = Vector3(0.08, 1.65, 1.85)
		curtain.position.z += 0.845
		await get_tree().process_frame
		if not cloth.transform.is_equal_approx(curtain.transform) or not is_equal_approx(cloth.mesh.get_aabb().size.z, 1.85):
			printerr("FAIL: curtain dressing does not follow source")
			failures += 1
		curtain.mesh.size = old_size
		curtain.position = old_position
		await get_tree().process_frame
		var lamp: Light3D = home.house.get_node("LivingLight")
		lamp.hide()
		await get_tree().process_frame
		if dressing.get_node("KitchenTask").visible or dressing.get_node("LivingLightDiffuser").material_override.emission_enabled:
			printerr("FAIL: light switch leaves new sources glowing")
			failures += 1
		lamp.show()
		await get_tree().process_frame
		if not dressing.get_node("KitchenTask").visible:
			printerr("FAIL: task lighting did not return")
			failures += 1
		var desk_lamp: Light3D = home.house.get_node("DeskLampLight")
		desk_lamp.hide()
		if desk_lamp.get_node("DeskTask").is_visible_in_tree():
			printerr("FAIL: desk switch leaves task light on")
			failures += 1
		desk_lamp.show()
	var folder := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
	if not folder.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(folder)
		home.get_node("HomeHUD/Screen").hide()
		main.get_node("NavigationHUD/Screen").hide()
		var camera := Camera3D.new()
		home.add_child(camera)
		camera.environment = home.rig.view.environment
		camera.fov = 66
		camera.make_current()
		var views := [
			["entry", Vector3(-1.65, 1.65, 2.35), Vector3(-2.1, 1.25, -1.0)],
			["living", Vector3(-0.65, 1.65, -0.3), Vector3(-3.1, 1.1, -2.6)],
			["kitchen", Vector3(-2.1, 1.65, -1.6), Vector3(-3.0, 1.25, -4.05)],
			["bedroom", Vector3(0.5, 1.65, 2.6), Vector3(2.1, 1.05, 0.2)],
			["desk", Vector3(1.15, 1.65, -1.65), Vector3(1.8, 1.3, -4.0)],
			["bathroom", Vector3(-3.55, 1.65, 1.85), Vector3(-4.25, 1.4, 0.85)],
		]
		for view in views:
			camera.position = view[1]
			camera.look_at(home.to_global(view[2]))
			for frame in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(folder.path_join(view[0] + ".png"))
		camera.queue_free()
	main.queue_free()
	await get_tree().process_frame
	print("PASS: house visual integrity" if failures == 0 else "FAIL: house visual integrity")
	get_tree().quit(0 if failures == 0 else 1)
