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
	_expect(model.skeleton.get_bone_count() == 15, "Fifteen bones for body, head, arms and legs")
	for index in model.skeleton.get_bone_count():
		var origin := model.skeleton.get_bone_global_pose(index).origin
		_expect(origin.is_finite(), "Finite bone transform")
	_expect(model.skeleton.get_bone_global_pose(2).origin.y > -0.01, "Head rest pose above pelvis")
	var count := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		count += 1
		_expect(node.mesh != null and node.mesh.get_aabb().size.length() > 0, "Nonempty mesh")
	_expect(count > 30, "Full body with clothing and fingers")
	var hand_before := model.skeleton.get_bone_pose_rotation(model.skeleton.find_bone("ForearmR"))
	await get_tree().create_timer(0.3).timeout
	_expect(model.skeleton.get_bone_pose_rotation(model.skeleton.find_bone("ForearmR")) != hand_before, "Idle pose evolves")
	var collider: Shape3D = guest.get_node("Collision").shape
	var transform_before := guest.transform
	var control: OptionButton = main.get_node("NavigationHUD/%TestFace")
	control.item_selected.emit(0)
	_expect(not model.visible and art.get_node("TestFace").visible, "Legacy comparison toggles whole body")
	control.item_selected.emit(3)
	_expect(model.visible and not art.get_node("TestFace").visible, "Menu restores model D")
	_expect(not art.set_test_appearance(&"bad") and model.visible, "Unknown appearance preserves model")
	rig.request_move(&"counter")
	await rig.anchor_reached
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
	main.queue_free()
	await get_tree().process_frame
	main = preload("res://scenes/main/main.tscn").instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	add_child(main)
	_expect(main.get_node("DialogueTrigger/Body").get_test_appearance() == &"test_visitor", "Model survives scene replacement")
	print("%s: visitor model, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
