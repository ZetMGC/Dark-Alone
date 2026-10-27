extends Node

var _checks: int = 0
var _failures: int = 0
var _capture: String = ""


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _aim(rig: FreeRoamCamera, point: Vector3) -> void:
	rig.reset_look()
	var current := -rig.view.global_basis.z.normalized()
	var direction := (point - rig.view.global_position).normalized()
	var yaw := atan2(-direction.x, -direction.z) - atan2(-current.x, -current.z)
	var pitch := asin(direction.y) - asin(current.y)
	rig.apply_look_delta(Vector2(yaw, pitch))


func _place(rig: FreeRoamCamera, feet: Vector3, point: Vector3) -> void:
	rig.body.global_position = feet
	rig.body.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().process_frame
	_aim(rig, point)
	await get_tree().physics_frame
	await get_tree().process_frame


func _point(rig: FreeRoamCamera, world: Vector3) -> void:
	var point := rig.view.unproject_position(world)
	get_viewport().warp_mouse(point)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	get_viewport().push_input(event, true)
	await get_tree().process_frame


func _snap(name: String) -> void:
	if _capture.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_expect(get_viewport().get_texture().get_image().save_png(_capture.path_join(name + ".png")) == OK, "Capture " + name)


func _run() -> void:
	get_tree().create_timer(25).timeout.connect(func() -> void:
		printerr("FAIL: world targeting timed out")
		get_tree().quit(1)
	)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(_capture)
	if "--small" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(960, 600)
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	var interaction: InteractionController = main.get_node("InteractionController")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var guest: ServiceGuest = main.get_node("DialogueTrigger")
	var counter: WorkstationTarget = main.get_node("CounterTarget")
	var hud: NavigationHUD = main.get_node("NavigationHUD")
	rig.fade_seconds = 0.01
	rig.black_hold_seconds = 0
	await get_tree().physics_frame
	_expect(not main.start_test_dialogue() and not interaction.try_interact(), "Remote guest and workstation inaccessible")
	_expect(not guest.get_node("Marker").visible and not rig.get_anchor(&"counter").get_node("Marker").visible, "Floating bar markers hidden")
	await _place(rig, Vector3(-1.2, 0, -1.2), guest.global_position)
	_expect(interaction.get_target() == guest and guest.is_available(), "Ray selects actual guest head in free walk")
	await _snap("01-guest-head")
	var approach := rig.body.global_position
	await _key(KEY_E)
	_expect(session.mode == NarrativeSession.DIALOGUE and not rig.focus_active and not rig.is_transitioning, "E starts dialogue without taking workstation")
	Input.action_press("move_forward")
	await get_tree().create_timer(0.08).timeout
	Input.action_release("move_forward")
	_expect(rig.body.global_position.distance_to(approach) > 0.05 and session.shift.remaining == 2 and session.runner.current_node_id == &"opening", "Direct conversation permits walking without restarting line or spending time")
	session.cancel_dialogue()
	_expect(session.shift.remaining == 2 and not rig.focus_active, "Cancel returns to free walk without spending time")
	_aim(rig, rig.view.global_position + Vector3.RIGHT * 4)
	await _key(KEY_E)
	_expect(session.mode == NarrativeSession.EXPLORATION and interaction.get_target() != guest, "E rechecks ray instead of activating stale guest")
	_aim(rig, guest.global_position + Vector3.DOWN * 0.65)
	_expect(interaction.get_target() == guest, "Guest torso is also a dialogue target")
	await _key(KEY_E)
	_expect(session.mode == NarrativeSession.DIALOGUE, "Torso starts same conversation")
	session.cancel_dialogue()
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2.5, 1)
	collision.shape = box
	wall.add_child(collision)
	main.add_child(wall)
	wall.global_position = Vector3(-1.85, 1.25, -1.2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_aim(rig, guest.global_position)
	_expect(interaction.get_target() == null and not main.start_test_dialogue(), "Wall blocks guest ray and shortcut")
	wall.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _place(rig, Vector3(-2.0, 0, 0.5), Vector3(-3.6, 1.08, 0.5))
	_expect(interaction.get_target() == null, "Front counter is furniture, not a workstation")
	await _key(KEY_E)
	_expect(not rig.focus_active, "Counter does not teleport across furniture from customer side")
	await _snap("02-counter-front")
	_aim(rig, Vector3(-3.0, 0.35, 0.5))
	_expect(interaction.get_target() == null, "Front counter base does not open back counter")
	await _place(rig, Vector3(-4.9, 0, -1.2), Vector3(-5.6, 1.06, -2))
	_expect(interaction.get_target() == counter and counter.is_available(), "Wooden countertop is target without aiming at invisible anchor")
	_aim(rig, Vector3(-5.5, 0.5, -2))
	_expect(interaction.get_target() == counter, "Back cabinet maps to workstation")
	_aim(rig, Vector3(-5.65, 2.65, -2))
	_expect(interaction.get_target() == counter, "Back shelves map to workstation")
	_aim(rig, Vector3(-5.6, 1.06, -2))
	await _key(KEY_E)
	while rig.is_transitioning:
		await get_tree().process_frame
	_expect(rig.focus_active and rig.current_anchor_id == &"back_counter" and interaction.pointer_mode, "E opens workstation and enables cursor targeting")
	_expect((-rig.view.global_basis.z).dot(Vector3.LEFT) > 0.85 and (-rig.view.global_basis.z).y < -0.3, "Workstation faces bottle shelves behind bartender")
	await _point(rig, Vector3(-5.6, 1.12, -2))
	_expect(interaction.get_target() == counter, "Cursor over back countertop selects workstation")
	_expect(hud.get_node("%Prompt").visible, "World hint remains visible at workstation")
	await _snap("03-back-counter")
	await _key(KEY_T)
	_expect(session.mode == NarrativeSession.DIALOGUE and not rig.focus_active, "Talk shortcut releases back counter into walking conversation")
	var talking_position := rig.body.global_position
	Input.action_press("move_back")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("move_back")
	_expect(rig.body.global_position.distance_to(talking_position) > 0.1 and session.runner.active, "Conversation from workstation allows physical movement")
	session.cancel_dialogue()
	await _place(rig, Vector3(-4.9, 0, -1.2), Vector3(-5.6, 1.06, -2))
	await _key(KEY_E)
	while rig.is_transitioning:
		await get_tree().process_frame
	await _point(rig, Vector3(-5.6, 1.12, -2))
	await _key(KEY_E)
	_expect(session.mode == NarrativeSession.SERVICE, "Counter action opens existing drink selection")
	_expect(not interaction.try_interact(), "Modal service blocks world interactions")
	session.close_service()
	session.open_menu()
	_expect(not interaction.try_interact() and not counter.is_available(), "Menu blocks mapped surface actions")
	session.resume_menu()
	await _key(KEY_ESCAPE)
	_expect(not rig.focus_active and not interaction.pointer_mode, "Leaving workstation restores centre ray")
	await _place(rig, Vector3(0, 0, 3.8), guest.global_position)
	_expect(not guest.is_available() and interaction.get_target() == null, "Walking away removes guest target")
	_expect(not interaction.register_surface(null, counter), "Invalid surface binding rejected")
	print("%s: world targeting, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
