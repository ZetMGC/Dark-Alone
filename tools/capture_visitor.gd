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
	key.shadow_enabled = true
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(8, 8)
	floor.mesh = floor_mesh
	floor.position.y = -1.65
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.07, 0.08, 0.09)
	floor_material.roughness = 1
	floor.material_override = floor_material
	stage.add_child(floor)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0.75, -0.33, 3.0)
	camera.look_at(Vector3(0, -0.6, 0))
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
		# Силуэт и анатомия проверяются отдельно от текстур.
		var clay := StandardMaterial3D.new()
		clay.albedo_color = Color(0.36, 0.37, 0.39)
		clay.roughness = 1
		model.get_node("CharacterMesh").material_override = clay
		for angle in [0, 65]:
			model.rotation.y = deg_to_rad(angle)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/visitor/clay_%d.png" % angle)
		model.get_node("CharacterMesh").material_override = null
		model.rotation.y = 0
		var wrist: Vector3 = model.to_global(model.skeleton.get_bone_global_pose(model.skeleton.find_bone("HandL")).origin)
		camera.position = wrist + Vector3(0.12, 0.13, 0.62)
		camera.look_at(wrist + Vector3(0.035, 0, 0.04))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/visitor/hand.png")
		var face: Vector3 = model.to_global(Vector3(0, -0.04, 0))
		camera.position = face + Vector3(0.18, 0.04, 1.08)
		camera.look_at(face)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/visitor/face.png")
		for side in [-1, 1]:
			camera.position = face + Vector3(side * 0.95, 0.015, 0)
			camera.look_at(face)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/visitor/profile_%s.png" % ("left" if side < 0 else "right"))
			model.get_node("CharacterMesh").material_override = clay
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/visitor/clay_profile_%s.png" % ("left" if side < 0 else "right"))
			model.get_node("CharacterMesh").material_override = null
		camera.position = face + Vector3(0.18, 0.04, 1.08)
		camera.look_at(face)
		var deadline := Time.get_ticks_msec() + 6000
		while not model.is_blinking:
			await process_frame
			if Time.get_ticks_msec() > deadline:
				printerr("FAIL: blink capture timed out")
				quit(1)
				return
		model.set_process(false)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/visitor/face_blink.png")
		# Экспортируем открытые глаза и текущую позу, без запечённых движений.
		model.set_process(true)
		while model.is_blinking:
			await process_frame
		model.set_process(false)
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
			var skeletons := restored.find_children("*", "Skeleton3D", true, false)
			print("GLB round trip skeletons: ", skeletons.size())
			if meshes.is_empty() or skeletons.size() != 1 or skeletons[0].get_bone_count() != 15:
				result = ERR_INVALID_DATA
			restored.free()
	print("Visitor GLB export: ", result)
	quit(0 if result == OK else 1)
