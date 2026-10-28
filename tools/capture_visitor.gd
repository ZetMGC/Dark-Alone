extends SceneTree
## Реальный GPU-снимок тестовой модели; --headless пригоден только для export.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1100, 850)
	var stage := Node3D.new()
	root.add_child(stage)
	var model := preload("res://scenes/characters/visitor_model.tscn").instantiate()
	stage.add_child(model)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.065, 0.072, 0.075)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.75, 0.8)
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, -30, 0)
	key.light_color = Color(1, 0.88, 0.73)
	key.light_energy = 1.4
	stage.add_child(key)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0.7, -0.45, 2.8)
	camera.look_at(Vector3(0, -0.65, 0))
	camera.fov = 43
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://artifacts/visitor")
	if DisplayServer.get_name() != "headless":
		for angle in [0, 65, 150]:
			model.rotation.y = deg_to_rad(angle)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/visitor/studio_%d.png" % angle)
		model.rotation.y = 0
		camera.position = Vector3(0.14, 0.02, 0.83)
		camera.look_at(Vector3(0, -0.02, 0))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/visitor/face.png")
	# Статическая переносимая модель для Blender; анимация остаётся в native-сцене.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_scene(model, state)
	if result == OK:
		result = document.write_to_filesystem(state, "res://artifacts/visitor/test_visitor.glb")
	if result == OK:
		var round_trip := GLTFState.new()
		result = document.append_from_file("res://artifacts/visitor/test_visitor.glb", round_trip)
		if result == OK:
			var restored := document.generate_scene(round_trip)
			var meshes := restored.find_children("*", "MeshInstance3D", true, false)
			print("GLB round trip meshes: ", meshes.size())
			if meshes.size() < 30:
				result = ERR_INVALID_DATA
			restored.free()
	print("Visitor GLB export: ", result)
	quit(0 if result == OK else 1)
