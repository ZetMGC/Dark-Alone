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


func _run() -> void:
	get_tree().create_timer(25).timeout.connect(func() -> void: get_tree().quit(1))
	get_window().size = Vector2i(1280, 720)
	var main := preload("res://scenes/main/main.tscn").instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	main.free_roam_enabled = false
	add_child(main)
	var art := main.get_node("DialogueTrigger/Body")
	var guest: ServiceGuest = main.get_node("DialogueTrigger")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var rig: AnchorCamera = main.get_node("AnchorCamera")
	var model: VisitorModel = art.get_node("VisitorModel")
	_expect(art.get_test_appearance() == &"test_visitor" and model.visible, "New TEST model is default")
	_expect(not art.get_node("TestFace").visible and not art.get_node("Torso").visible, "No overlapping legacy geometry")
	_expect(model.scale.is_equal_approx(Vector3.ONE * (1.048 * 1.05)), "Five percent larger than player height iteration")
	_expect(absf(model.to_global(Vector3(0, -1.65, 0)).y) < 0.001, "Scale is anchored at original floor")
	var walking: CollisionShape3D = guest.get_node("WalkObstacle/Shape")
	_expect(absf(walking.shape.radius - 0.26 * 1.1004) < 0.001 and absf(walking.shape.height - 1.65 * 1.1004) < 0.001, "Walking volume follows current body size")
	_expect(absf(walking.global_position.y - walking.shape.height / 2.0) < 0.001, "Walking collider remains grounded")
	_expect(guest.get_dialogue_head_position().y > guest.get_dialogue_face_position().y and absf(guest.get_dialogue_face_position().y - 1.735) < 0.04, "Speech anchors follow slightly taller body")
	_expect(not guest.configure_body_scale(NAN) and not guest.configure_body_scale(-1.0), "Invalid body scale is rejected")
	_expect(model.skeleton.get_bone_count() == 15, "Fifteen bones for body, head, arms and legs")
	for index in model.skeleton.get_bone_count():
		var origin := model.skeleton.get_bone_global_pose(index).origin
		_expect(origin.is_finite(), "Finite bone transform")
	_expect(model.skeleton.get_bone_global_pose(2).origin.y > model.skeleton.get_bone_global_pose(1).origin.y, "Head rest pose above chest")
	var count := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		count += 1
		_expect(node.mesh != null and node.mesh.get_aabb().size.length() > 0, "Nonempty mesh")
	var character: MeshInstance3D = model.get_node("CharacterMesh")
	_expect(character.skin != null and character.skin.get_bind_count() == 15, "Real skin with fifteen inverse rest binds")
	_expect(character.mesh.get_surface_count() == 3, "Skin, clothing and leather surfaces")
	var blended := 0
	var vertex_count := 0
	var clothing_arrays: Array = []
	var palm_sum := Vector3.ZERO
	var palm_count := 0
	var nose_depth := 0.0
	var chin_depth := 0.0
	var mouth_depth := 0.0
	var jaw_transition_depth := 0.0
	var head_origin := model.skeleton.get_bone_global_rest(model.skeleton.find_bone("Head")).origin
	for surface in character.mesh.get_surface_count():
		var arrays: Array = character.mesh.surface_get_arrays(surface)
		var material: StandardMaterial3D = character.mesh.surface_get_material(surface)
		if material.albedo_texture and material.albedo_texture.resource_path.ends_with("clothing_atlas_v3.png"):
			clothing_arrays = arrays
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		vertex_count += vertices.size()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var coordinates: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		_expect(bones.size() == vertices.size() * 4 and weights.size() == vertices.size() * 4, "Every vertex is bound")
		var valid := true
		for vertex in vertices.size():
			if bones[vertex * 4] == model.skeleton.find_bone("Head"):
				var local := vertices[vertex] - head_origin
				var source_y := (local.y + 0.016) / 0.92
				if absf(local.x) < 0.002:
					if source_y >= -0.052 and source_y <= -0.022:
						nose_depth = maxf(nose_depth, local.z)
					if source_y >= -0.135 and source_y <= -0.110:
						chin_depth = maxf(chin_depth, local.z)
					if source_y >= -0.09 and source_y <= -0.06:
						mouth_depth = maxf(mouth_depth, local.z)
					if source_y >= -0.10 and source_y <= -0.09:
						jaw_transition_depth = maxf(jaw_transition_depth, local.z)
			if bones[vertex * 4] == model.skeleton.find_bone("HandL") and weights[vertex * 4] > 0.99:
				palm_sum += vertices[vertex]
				palm_count += 1
			var total: float = 0
			for influence in 4:
				var index := vertex * 4 + influence
				valid = valid and bones[index] >= 0 and bones[index] < 15 and is_finite(weights[index]) and weights[index] >= 0
				total += weights[index]
			valid = valid and absf(total - 1.0) < 0.0001 and vertices[vertex].is_finite()
			valid = valid and normals[vertex].is_finite() and absf(normals[vertex].length() - 1.0) < 0.001
			valid = valid and coordinates[vertex].is_finite() and Rect2(-0.001, -0.001, 1.002, 1.002).has_point(coordinates[vertex])
			if weights[vertex * 4] > 0 and weights[vertex * 4 + 1] > 0:
				blended += 1
		_expect(valid, "Finite skin vertices normals UV and normalized weights")
	_expect(blended > 100, "Soft transitions across elbows knees and waist")
	_expect(nose_depth - chin_depth > 0.012 and nose_depth - chin_depth < 0.045, "Profile has a separate nose and supported chin instead of a beak")
	_expect(chin_depth > mouth_depth - 0.015, "Chin no longer collapses behind mouth")
	_expect(jaw_transition_depth > mouth_depth - 0.012, "No deep notch between lower lip and chin")
	var wrist := model.skeleton.get_bone_global_rest(model.skeleton.find_bone("HandL")).origin
	var elbow := model.skeleton.get_bone_global_rest(model.skeleton.find_bone("ForearmL")).origin
	_expect(palm_count > 20 and (palm_sum / maxf(palm_count, 1) - wrist).normalized().dot((wrist - elbow).normalized()) > 0.90, "Palm geometry follows forearm instead of sideways wrist")
	_expect(model.skeleton.get_bone_pose_rotation(model.skeleton.find_bone("HandL")).get_angle() < 0.2, "Resting wrist has no excessive pose twist")
	_expect(vertex_count < 15000, "Prototype vertex budget remains bounded")
	# Освещение должно видеть наружную сторону рукавов, а не внутреннюю изнанку.
	for suffix in ["L", "R"]:
		var start := model.skeleton.get_bone_global_rest(model.skeleton.find_bone("UpperArm" + suffix)).origin
		var end := model.skeleton.get_bone_global_rest(model.skeleton.find_bone("Forearm" + suffix)).origin
		var outward := (end - start).cross(Vector3.RIGHT).normalized()
		var target := start.lerp(end, 0.32) + outward * 0.081
		var distance := INF
		var facing := -1.0
		for index in clothing_arrays[Mesh.ARRAY_VERTEX].size():
			var candidate: Vector3 = clothing_arrays[Mesh.ARRAY_VERTEX][index]
			if candidate.distance_to(target) < distance:
				distance = candidate.distance_to(target)
				facing = clothing_arrays[Mesh.ARRAY_NORMAL][index].dot(outward)
		_expect(distance < 0.01 and facing > 0.5, "Sleeve normals face outwards " + suffix)
	var hand_before := model.skeleton.get_bone_pose_rotation(model.skeleton.find_bone("Head"))
	await get_tree().create_timer(0.3).timeout
	_expect(model.skeleton.get_bone_pose_rotation(model.skeleton.find_bone("Head")) != hand_before, "Idle pose evolves")
	var frozen := model.skeleton.get_bone_pose_rotation(2)
	model.hide()
	await get_tree().create_timer(0.18).timeout
	_expect(model.skeleton.get_bone_pose_rotation(2) == frozen, "Hidden model freezes animation")
	model.show()
	get_tree().paused = true
	await get_tree().create_timer(0.18, true).timeout
	_expect(model.skeleton.get_bone_pose_rotation(2) == frozen, "Tree pause freezes animation")
	get_tree().paused = false
	var collider: Shape3D = guest.get_node("Collision").shape
	var transform_before := guest.transform
	var control: OptionButton = main.get_node("NavigationHUD/%TestFace")
	control.item_selected.emit(0)
	_expect(not model.visible and art.get_node("TestFace").visible, "Legacy comparison toggles whole body")
	_expect(absf(walking.shape.radius - 0.26) < 0.001 and absf(walking.shape.height - 1.65) < 0.001, "Legacy variants restore original walking volume")
	control.item_selected.emit(3)
	_expect(model.visible and not art.get_node("TestFace").visible, "Menu restores model D")
	_expect(not art.set_test_appearance(&"bad") and model.visible, "Unknown appearance preserves model")
	rig.request_move(&"counter")
	await rig.anchor_reached
	await get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(rig.view.global_position, guest.get_dialogue_face_position(), 2)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(query)
	_expect(hit.get("collider") == guest, "Ray to enlarged face reaches guest interaction volume")
	main.start_test_dialogue()
	_expect(session.mode == NarrativeSession.DIALOGUE and model.talking, "Conversation enables gesture")
	var node_before := session.runner.current_node_id
	art.set_test_appearance(&"test_face_b")
	art.set_test_appearance(&"test_visitor")
	_expect(session.runner.current_node_id == node_before, "Appearance keeps dialogue state")
	session.cancel_dialogue()
	_expect(not model.talking, "Gesture stops outside conversation")
	main.open_service_menu()
	session.serve_drink(&"test_water")
	_expect(session.service.served and guest.get_node("ServedGlass").visible, "Drink remains visible")
	_expect(guest.get_node("Collision").shape == collider and guest.transform == transform_before, "Collider and guest location preserved")
	if DisplayServer.get_name() != "headless":
		main.get_node("NavigationHUD/Screen").hide()
		guest.get_node("ServedGlass/Label").hide()
		DirAccess.make_dir_recursive_absolute("res://artifacts/visitor")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_expect(get_viewport().get_texture().get_image().save_png("res://artifacts/visitor/bar.png") == OK, "Capture actual bar view")
		guest.get_node("Marker").hide()
		rig.view.fov = 35
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_expect(get_viewport().get_texture().get_image().save_png("res://artifacts/visitor/bar_close.png") == OK, "Capture inspection zoom without moving camera")
	var deadline := Time.get_ticks_msec() + 6000
	while not model.is_blinking and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.015).timeout
	_expect(model.is_blinking, "Blink occurs during live animation")
	var blink_texture_found := false
	for surface in character.mesh.get_surface_count():
		var material: StandardMaterial3D = character.mesh.surface_get_material(surface)
		if material.albedo_texture and material.albedo_texture.resource_path.ends_with("head_blink_v3.png"):
			blink_texture_found = true
			_expect(material.albedo_texture.get_size() == Vector2(512, 512), "Blink atlas matches open atlas size")
	_expect(blink_texture_found, "Blink changes actual diffuse texture, no overlay")
	deadline = Time.get_ticks_msec() + 1000
	while model.is_blinking and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.015).timeout
	_expect(not model.is_blinking, "Blink reopens eyes")
	print("Visitor geometry: ", vertex_count, " vertices, ", blended, " blended vertices")
	main.queue_free()
	await get_tree().process_frame
	main = preload("res://scenes/main/main.tscn").instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	add_child(main)
	_expect(main.get_node("DialogueTrigger/Body").get_test_appearance() == &"test_visitor", "Model survives scene replacement")
	print("%s: visitor model, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
