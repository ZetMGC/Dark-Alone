extends Node
var checks: int = 0
var failures: int = 0
var capture: String = ""
func _ready() -> void:
	run.call_deferred()
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func key_e() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_E
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame
	await get_tree().process_frame
func aim(rig: FreeRoamCamera, point: Vector3) -> void:
	rig.reset_look()
	var current := -rig.view.global_basis.z.normalized()
	var direction := (point - rig.view.global_position).normalized()
	rig.apply_look_delta(Vector2(atan2(-direction.x, -direction.z) - atan2(-current.x, -current.z), asin(direction.y) - asin(current.y)))
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
func snap(name: String) -> void:
	if capture.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	expect(get_viewport().get_texture().get_image().save_png(capture.path_join(name + ".png")) == OK, "Capture " + name)
func run() -> void:
	get_tree().create_timer(35).timeout.connect(func() -> void: get_tree().quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture)
	if "--small" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(960, 600)
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var carry = main.drink_carry
	rig.set_process_unhandled_input(false)
	rig.body.global_position = Vector3(-4.9, 0, -2)
	for frame in 3:
		await get_tree().physics_frame
		await get_tree().process_frame
	rig.fade_seconds = 0.01
	rig.black_hold_seconds = 0
	expect(rig.request_move(&"back_counter"), "Approach work surface")
	while rig.is_transitioning:
		await get_tree().process_frame
	expect(main.open_service_menu(), "Open preparation")
	var bench: DrinkWorkbench = main.get_node("ServicePanel").workbench
	expect(bench.world_output and bench.preparation.pour(&"carry_base", &"test_base", 20), "Prepare physical portion")
	bench.begin_drag(&"cup", bench.get_item_position(&"cup"))
	bench.drag_to(DrinkWorkbench.SERVE_ZONE.get_center())
	bench.end_drag()
	expect(bench.request_delivery(), "Finish drink into world")
	expect(is_instance_valid(carry.item) and not carry.holding and not session.service.served and session.shift.remaining == 2, "Finished drink waits in workspace without serving or time cost")
	expect(bench.preparation.get_result().is_empty() and not bench.begin_drag(&"cup", bench.get_item_position(&"cup")), "Transferred portion cannot be edited or duplicated in workbench")
	expect(not main._stage_physical_drink(bench.preparation), "Cannot stage same portion twice")
	expect(is_equal_approx(carry.item.global_position.y, 1.13) and carry.item.get_node_or_null("GlassVisual/Contents/Layer0") != null, "Drink with real liquid rests on work surface")
	var id: int = carry.item.get_instance_id()
	if rig.focus_active:
		rig.leave_focus()
	await aim(rig, carry.item.global_position + Vector3.UP * 0.06)
	expect(main.get_node("InteractionController").get_target() == carry.item, "Real ray targets drink")
	await snap("01-ready-on-surface")
	await key_e()
	expect(carry.holding and carry.item.get_parent() == rig.view, "E picks up same world object into camera hand")
	expect(carry.item.collision_layer == 0 and not carry.item.is_available() and not carry.pick_up(), "Held item cannot occlude interaction ray or be duplicated")
	await get_tree().create_timer(0.5).timeout
	var point := rig.view.unproject_position(carry.item.global_position + Vector3.UP * 0.05)
	expect(point.x > get_viewport().get_visible_rect().size.x * 0.5 and point.y > get_viewport().get_visible_rect().size.y * 0.5, "Held drink appears in right lower screen")
	expect(carry.item.get_node_or_null("Hand") == null, "No hand model or texture")
	await snap("02-held")
	var frozen: Vector3 = carry.offset
	expect(session.open_menu(), "Open pause while holding")
	carry._process(0.05)
	expect(carry.offset == frozen and carry.holding, "Pause freezes spring without dropping portion")
	expect(session.resume_menu(), "Resume holding")
	await aim(rig, Vector3(-5.6, 1.08, -2))
	expect(main.get_node("InteractionController").get_target() == main.get_node("CounterTarget"), "Held cup does not block surface ray")
	await key_e()
	expect(not carry.holding and carry.item.get_instance_id() == id and carry.item.collision_layer == 2, "E places same drink back without duplication")
	expect(carry.item.get_parent() == main and carry.item.global_position.is_equal_approx(carry.home_position), "Placed drink returns to supported world position")
	await aim(rig, carry.item.global_position + Vector3.UP * 0.06)
	await key_e()
	expect(carry.holding, "Placed drink can be picked up again")
	expect(main.start_test_dialogue(), "Conversation can continue while carrying")
	rig.body.global_position = Vector3(-1.2, 0, -1.2)
	for frame in 3:
		await get_tree().physics_frame
		await get_tree().process_frame
	await aim(rig, main.get_node("DialogueTrigger").global_position)
	expect(main.get_node("InteractionController").get_target() == main.get_node("DialogueTrigger"), "Carry to actual guest")
	await snap("03-carry-to-guest")
	await key_e()
	expect(session.service.served and not carry.holding and carry.item == null and session.shift.remaining == 1, "E serves carried portion once and consumes one division")
	expect(session.runner.active and session.mode == NarrativeSession.DIALOGUE, "Hand delivery preserves active conversation")
	expect(session.service.get_prepared_drink().get("overall", {}).get("components", {}).get("test_base", 0) == 20, "Delivered composition preserved exactly")
	expect(not main._deliver_carried_drink() and session.shift.remaining == 1, "Duplicate delivery cannot spend time twice")
	expect(main.get_node("DialogueTrigger/ServedGlass").visible, "Delivered cup appears by guest")
	await snap("04-delivered")
	var spring = load("res://scripts/player/drink_carry.gd").new()
	for frame in 60:
		spring.advance_motion(1.0 / 60, Vector3(0, 4, 0), Vector3.ZERO)
	expect(spring.offset.x > 0.01 and spring.tilt.z < -0.02, "Turning camera produces lag and tilt")
	expect(spring.offset.length() < 0.1 and spring.tilt.length() < 0.4, "Fast camera sway remains bounded")
	for frame in 240:
		spring.advance_motion(1.0 / 120, Vector3.ZERO, Vector3.ZERO)
	expect(spring.offset.length() < 0.001 and spring.tilt.length() < 0.001, "Spring settles without jitter")
	for frame in 60:
		spring.advance_motion(1.0 / 60, Vector3(4, 0, 0), Vector3.ZERO)
	expect(spring.offset.y < -0.01 and spring.tilt.x < -0.02, "Looking up makes held cup lag downward")
	for frame in 60:
		spring.advance_motion(1.0 / 60, Vector3.ZERO, Vector3(2, 0, 0))
	expect(spring.offset.x < -0.01, "Walking right makes held cup lag left")
	var coarse = load("res://scripts/player/drink_carry.gd").new()
	var fine = load("res://scripts/player/drink_carry.gd").new()
	for frame in 30:
		coarse.advance_motion(1.0 / 30, Vector3(0, 4, 0), Vector3.ZERO)
	for frame in 120:
		fine.advance_motion(1.0 / 120, Vector3(0, 4, 0), Vector3.ZERO)
	expect(coarse.offset.distance_to(fine.offset) < 0.0001 and coarse.tilt.distance_to(fine.tilt) < 0.0001, "Spring consistent at 30 and 120 FPS")
	spring.free()
	coarse.free()
	fine.free()
	print("%s: drink carry, %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
