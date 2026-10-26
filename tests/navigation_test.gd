extends SceneTree
## Поведенческие проверки M1 в настоящем дереве сцены и физическом мире.

var _failures: int = 0
var _checks: int = 0
var _started: Array[StringName] = []
var _reached: Array[StringName] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	JournalPanel.motion_mode = &"off"
	create_timer(20.0).timeout.connect(func() -> void:
		printerr("FAIL: navigation test timed out")
		quit(1)
	)
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	root.add_child(main)
	await process_frame
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var interaction := main.get_node("InteractionController") as InteractionController
	var anchors := main.get_node("BarLevel/Anchors") as Node3D
	rig.fade_seconds = 0.02
	rig.black_hold_seconds = 0.02
	rig.transition_started.connect(func(_from: StringName, to: StringName) -> void:
		_started.append(to)
		_expect(not rig.request_move(to), "Reentrant request must be rejected")
	)
	rig.anchor_reached.connect(func(id: StringName) -> void: _reached.append(id))
	_expect(rig.current_anchor_id == &"entry", "Start at entry")
	_expect(_started.is_empty() and _reached.is_empty(), "Initial placement has no travel signals")
	_expect(rig.get_anchors().size() == 4, "Four anchors registered")
	_expect(not rig.request_move(&"missing"), "Unknown destination rejected")
	_expect(not rig.request_move(&"entry"), "Current destination rejected")
	_expect(not rig.request_move(&"table"), "Non-neighbour destination rejected")
	_expect(_started.is_empty(), "Rejected requests do not emit start")

	# Конечные позы должны быть вне геометрии, даже если переход скрыт fade.
	await physics_frame
	for anchor in rig.get_anchors():
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.12
		query.shape = shape
		query.transform = anchor.global_transform
		query.collision_mask = 1
		_expect(rig.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
			"Camera pose outside geometry: " + str(anchor.anchor_id))

	# Все направленные связи кольца: прямой и обратный обход.
	for destination: StringName in [&"counter", &"table", &"corner", &"entry", &"corner", &"table", &"counter", &"entry"]:
		var before := rig.global_transform
		var start_count := _started.size()
		var finish_count := _reached.size()
		_expect(rig.request_move(destination), "Neighbour request accepted: " + str(destination))
		_expect(rig.global_transform == before, "No teleport before fade-out")
		_expect(not rig.request_move(destination), "Repeated request rejected during fade")
		var deadline := Time.get_ticks_msec() + 3000
		while rig.is_transitioning and Time.get_ticks_msec() < deadline:
			if not rig.global_transform.is_equal_approx(before):
				_expect(rig.global_transform.is_equal_approx(rig.get_anchor(destination).global_transform),
					"Camera uses only endpoint poses")
			await process_frame
		_expect(not rig.is_transitioning, "Transition completes within deadline")
		_expect(rig.current_anchor_id == destination, "Current ID updates on arrival")
		_expect(_started.size() == start_count + 1, "Exactly one start signal")
		_expect(_reached.size() == finish_count + 1, "Exactly one arrival signal")
		_expect(rig.global_transform.is_equal_approx(rig.get_anchor(destination).global_transform), "Destination pose applied")
		_expect(is_zero_approx(rig.get_node("FadeLayer/Fade").color.a), "Fade clears on arrival")
		if rig.is_transitioning:
			quit(1)
			return

	# Обзор ограничен; блокировка ввода не меняет направление или позицию.
	rig.apply_look_delta(Vector2(1.0, 100.0))
	_expect(is_equal_approx(rig.view.rotation.x, deg_to_rad(65)), "Vertical look clamped")
	var look_before := rig.view.rotation
	rig.set_controls_enabled(false)
	rig.apply_look_delta(Vector2(1, -1))
	_expect(rig.view.rotation == look_before, "Locked look unchanged")
	_expect(not rig.request_move(&"counter"), "Locked movement rejected")
	rig.set_controls_enabled(true)
	rig.reset_look()
	_expect(rig.view.rotation == Vector3.ZERO, "Look reset uses anchor heading")

	await _test_ray_occlusion(main, rig, interaction)
	# Из стойки вернуться ко входу для теста настоящих событий InputMap.
	if rig.current_anchor_id == &"counter":
		rig.request_move(&"entry")
		await rig.anchor_reached
	_send_key(KEY_ESCAPE)
	await process_frame
	_expect(main.get_node("NavigationHUD/Screen/Menu").visible, "Escape opens menu")
	_send_key(KEY_2)
	await process_frame
	_expect(not rig.is_transitioning, "Menu blocks navigation shortcut")
	_expect(not interaction.activate(rig.get_anchor(&"counter")), "Menu blocks interactions")
	_send_key(KEY_ESCAPE)
	await process_frame
	_expect(not main.get_node("NavigationHUD/Screen/Menu").visible, "Escape closes menu")
	_send_key(KEY_3)
	await process_frame
	_expect(not rig.is_transitioning, "Shortcut to non-neighbour rejected")
	_send_key(KEY_2)
	await process_frame
	_expect(rig.is_transitioning, "Shortcut starts reachable transition")
	if rig.is_transitioning:
		await rig.anchor_reached
	_expect(rig.current_anchor_id == &"counter", "Shortcut reaches counter")
	main.get_node("NavigationHUD").destination_requested.emit(&"table")
	_expect(rig.is_transitioning, "HUD route command starts transition")
	if rig.is_transitioning:
		await rig.anchor_reached
	_expect(rig.current_anchor_id == &"table", "HUD reaches table")

	_test_invalid_graphs(rig, anchors)
	main.queue_free()
	await process_frame
	print("%s: M1 navigation, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_ray_occlusion(main: Node, rig: AnchorCamera, interaction: InteractionController) -> void:
	var destination := rig.get_anchor(&"counter")
	var direction := rig.view.global_position.direction_to(destination.global_position)
	rig.apply_look_delta(Vector2(atan2(-direction.x, -direction.z), asin(direction.y)))
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE
	collision.shape = shape
	blocker.add_child(collision)
	main.add_child(blocker)
	blocker.global_position = rig.view.global_position.lerp(destination.global_position, 0.5)
	await physics_frame
	await physics_frame
	await process_frame
	_expect(not interaction.try_interact(), "Solid geometry blocks ray interaction")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	await process_frame
	_expect(interaction.try_interact(), "Visible available target accepts interaction")
	if rig.is_transitioning:
		await rig.anchor_reached
	_expect(rig.current_anchor_id == &"counter", "Ray interaction reaches target")


func _send_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.physical_keycode = key
	Input.parse_input_event(release)


func _test_invalid_graphs(rig: AnchorCamera, original: Node3D) -> void:
	var entry := original.get_node("Entry") as AnchorPoint
	var counter := original.get_node("Counter") as AnchorPoint
	var original_id := rig.current_anchor_id
	var original_pose := rig.global_transform
	var saved_id := counter.anchor_id
	counter.anchor_id = entry.anchor_id
	_expect(not rig.configure(original, &"entry"), "Duplicate IDs rejected")
	counter.anchor_id = saved_id
	var saved_neighbours := entry.neighbours.duplicate()
	for invalid: PackedStringArray in [PackedStringArray(["unknown"]), PackedStringArray(["entry"]), PackedStringArray(["counter", "counter"])]:
		entry.neighbours = invalid
		_expect(not rig.configure(original, &"entry"), "Invalid graph edge rejected")
	entry.neighbours = saved_neighbours
	entry.anchor_id = &""
	_expect(not rig.configure(original, &"counter"), "Empty ID rejected")
	entry.anchor_id = &"entry"
	_expect(not rig.configure(original, &"missing"), "Unknown initial anchor rejected")
	var saved_scale := entry.scale
	entry.scale = Vector3(2, 1, 1)
	_expect(not rig.configure(original, &"entry"), "Scaled camera pose rejected")
	entry.scale = saved_scale
	_expect(rig.current_anchor_id == original_id and rig.global_transform == original_pose,
		"Rejected configuration preserves current state")
	var empty := Node3D.new()
	root.add_child(empty)
	_expect(not rig.configure(empty, &"entry"), "Empty graph rejected")
	empty.queue_free()
