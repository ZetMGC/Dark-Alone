extends SceneTree

var _output: String
var _suffix: String = ""


func _initialize() -> void:
	_capture.call_deferred()


func _save(name: String) -> void:
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_output.path_join("da035_" + name + _suffix + ".png"))
	if error != OK:
		push_error("Cannot save face preview")
		quit(1)


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Face previews require graphical renderer")
		quit(1)
		return
	JournalPanel.motion_mode = &"off"
	if "--small" in OS.get_cmdline_user_args():
		_suffix = "_small"
		root.size = Vector2i(960, 600)
	_output = ProjectSettings.globalize_path("res://artifacts/da035-faces")
	DirAccess.make_dir_recursive_absolute(_output)
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	main.free_roam_enabled = false
	root.add_child(main)
	current_scene = main
	var rig: AnchorCamera = main.get_node("AnchorCamera")
	rig.request_move(&"counter")
	await rig.anchor_reached
	var art := main.get_node("DialogueTrigger/Body")
	var presentation: PresentationController = main.get_node("Presentation")
	main.get_node("NavigationHUD/Screen").hide()
	main.get_node("DialogueTrigger/Marker").hide()
	for id in TestFace.get_appearance_ids():
		art.set_test_appearance(id)
		for mode in [&"adaptive", &"classic"]:
			presentation.set_image_detail(mode)
			await _save(str(id) + "_counter_" + str(mode))
	main.get_node("NavigationHUD/Screen").show()
	main.get_node("NarrativeSession").open_menu()
	await _save("settings")
	main.get_node("NarrativeSession").resume_menu()
	main.get_node("NavigationHUD/Screen").hide()
	main.get_node("BarLevel").hide()
	main.get_node("DialogueTrigger").hide()
	presentation.set_retro_enabled(false)
	var environment_node: WorldEnvironment = main.get_node("BarLevel/WorldEnvironment")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.115, 0.12, 0.125)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = environment
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 65, 0)
	key.light_energy = 1.0
	main.add_child(key)
	var camera := Camera3D.new()
	camera.position = Vector3(0.95, 0.025, 0)
	camera.fov = 38
	main.add_child(camera)
	camera.look_at(Vector3(0, 0.02, 0))
	camera.make_current()
	var face := (load("res://scenes/characters/test_face.tscn") as PackedScene).instantiate() as TestFace
	main.add_child(face)
	for id in TestFace.get_appearance_ids():
		face.set_appearance(id)
		camera.position = Vector3(0.95, 0.025, 0)
		camera.look_at(Vector3(0, 0.02, 0))
		await _save(str(id) + "_portrait")
		camera.position = Vector3(0.80, 0.025, 0.48)
		camera.look_at(Vector3(0, 0.02, 0))
		await _save(str(id) + "_three_quarter")
	face.set_appearance(&"test_face_a")
	face.position.z = 0.55
	for index in [1, 2]:
		var other := (load("res://scenes/characters/test_face.tscn") as PackedScene).instantiate() as TestFace
		other.set_appearance(TestFace.get_appearance_ids()[index])
		other.position.z = 0.55 - float(index) * 0.55
		main.add_child(other)
	camera.position = Vector3(1.8, 0.025, 0)
	camera.fov = 32
	camera.look_at(Vector3(0, 0.02, 0))
	await _save("comparison")
	print("PASS: face previews " + _output)
	current_scene = null
	main.queue_free()
	await process_frame
	await process_frame
	quit()
