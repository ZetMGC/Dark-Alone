extends Node

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _frame() -> void:
	await get_tree().create_timer(0.12).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _valid_geometry(face: TestFace) -> bool:
	for part in face.get_node("Anatomy").get_children():
		if not part is MeshInstance3D or part.mesh == null:
			return false
		var bounds: AABB = part.mesh.get_aabb()
		if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.length() == 0:
			return false
		if part.mesh is ArrayMesh:
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for index in range(0, vertices.size(), 3):
				if (vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).length() < 0.0000001:
					return false
			for normal in normals:
				if not normal.is_finite() or not is_equal_approx(normal.length(), 1.0):
					return false
	return true


func _run() -> void:
	get_tree().create_timer(35).timeout.connect(func() -> void:
		printerr("FAIL: face tests timed out")
		get_tree().quit(1)
	)
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := scene.instantiate()
	main.checkpoint_enabled = false
	get_tree().root.add_child(main)
	var art := main.get_node("DialogueTrigger/Body")
	var face: TestFace = art.get_node("TestFace")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var rig: AnchorCamera = main.get_node("AnchorCamera")
	var guest: ServiceGuest = main.get_node("DialogueTrigger")
	var ids := TestFace.get_appearance_ids()
	_expect(ids.size() == 3, "Three neutral TEST morphologies available")
	var coat: Material = art.get_node("Torso").material_override
	var target: Shape3D = guest.get_node("Collision").shape
	var old_transform := guest.transform
	var profiles: Array[Dictionary] = []
	for id in ids:
		_expect(art.set_test_appearance(id) and art.get_test_appearance() == id, "Accepted profile " + str(id))
		_expect(_valid_geometry(face), "Finite nondegenerate geometry and normals " + str(id))
		profiles.append(face.get_profile())
		_expect(face.get_child_count() == 1 and art.get_node("Torso").material_override == coat, "Rebuild preserves one anatomy and same clothes")
		_expect(guest.get_node("Collision").shape == target and guest.transform == old_transform, "Face does not move guest or target")
	_expect(profiles[0].height > profiles[1].height and profiles[1].width > profiles[0].width and profiles[2].asymmetry > profiles[0].asymmetry, "Differences are anatomical rather than color labels")
	var copy := face.get_profile()
	copy.width = 99.0
	_expect(face.get_profile().width < 1.0, "Profile data returned by copy")
	_expect(not art.set_test_appearance(&"unknown") and art.get_test_appearance() == ids[2], "Unknown appearance cannot erase face")
	main.get_node("NavigationHUD/%TestFace").item_selected.emit(0)
	_expect(art.get_test_appearance() == ids[0], "Menu switches the actual guest")
	rig.request_move(&"counter")
	await rig.anchor_reached
	_expect(guest.is_available(), "Same interaction target available at counter")
	main.start_test_dialogue()
	var node_before := session.runner.current_node_id
	art.set_test_appearance(ids[1])
	_expect(session.mode == NarrativeSession.DIALOGUE and session.runner.current_node_id == node_before, "Appearance preserves active conversation")
	session.cancel_dialogue()
	main.open_service_menu()
	session.serve_drink(&"test_water")
	art.set_test_appearance(ids[2])
	_expect(session.service.served and guest.get_node("ServedGlass").visible and session.shift.remaining == 1, "Face switch preserves drink and event time")
	if DisplayServer.get_name() != "headless":
		main.get_node("NavigationHUD/Screen").hide()
		guest.get_node("Marker").hide()
		guest.get_node("ServedGlass/Label").hide()
		var presentation: PresentationController = main.get_node("Presentation")
		for size in [Vector2i(960, 600), Vector2i(1920, 1080)]:
			get_window().size = size
			for detail in [&"adaptive", &"classic"]:
				presentation.set_image_detail(detail)
				var hashes: Array[int] = []
				for id in ids:
					art.set_test_appearance(id)
					await _frame()
					var image := get_viewport().get_texture().get_image()
					hashes.append(hash(image.get_data()))
					_expect(image.get_size() == size, "Rendered native size")
					for argument in OS.get_cmdline_user_args():
						if argument.begins_with("--capture-dir="):
							var folder := argument.trim_prefix("--capture-dir=")
							DirAccess.make_dir_recursive_absolute(folder)
							_expect(image.save_png(folder.path_join("da035_%s_%s_%dx%d.png" % [id, detail, size.x, size.y])) == OK, "Capture actual guest")
				_expect(hashes[0] != hashes[1] and hashes[1] != hashes[2] and hashes[0] != hashes[2], "Unlabelled rendered faces remain distinct")
		presentation.set_image_detail(&"adaptive")
	art.set_test_appearance(ids[1])
	main.queue_free()
	await get_tree().process_frame
	main = scene.instantiate()
	main.checkpoint_enabled = false
	get_tree().root.add_child(main)
	art = main.get_node("DialogueTrigger/Body")
	_expect(art.get_test_appearance() == ids[1] and main.get_node("NavigationHUD/%TestFace").selected == 1, "TEST appearance survives scene replacement")
	_expect(not main.get_node("NarrativeSession").service.served, "New game still owns its own order")
	art.set_test_appearance(ids[0])
	print("%s: test faces, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
