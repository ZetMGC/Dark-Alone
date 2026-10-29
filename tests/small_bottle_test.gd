extends Node
var checks := 0
var failures := 0
var capture_root := "res://artifacts"
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)
func _ready() -> void:
	run.call_deferred()
func click(bench: DrinkWorkbench, point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = bench.logical_to_screen(point)
		get_viewport().push_input(event, true)
	await get_tree().process_frame

func wait_cap(bench: DrinkWorkbench) -> void:
	bench.cap_item.advance(BottleCapItem.DURATION)
	await get_tree().process_frame
func run() -> void:
	if not OS.has_feature("editor"):
		capture_root = "user://da090-captures"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_root))
	if "--small" in OS.get_cmdline_user_args(): get_window().size = Vector2i(960, 600)
	var main = load("res://scenes/main/reasoning_demo.tscn").instantiate()
	main.visitor_behavior_enabled = false
	main.preferences_enabled = false
	main.checkpoint_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	var bench: DrinkWorkbench = main.get_node("ServicePanel").workbench
	var store = main.supplies
	var id := SmallBottleVisual.ID
	var bottle = store.bottle_nodes[id]
	var visual: SmallBottleVisual = bottle.get_node("BottleVisual")
	expect(bench.get_bottle_remaining(id) == 250, "New small bottle contains 250 ml")
	expect(bench.is_bottle_capped(id) and visual.cap.visible, "Closed in both representations")
	expect(not bench.toggle_bottle_cap(id), "Unavailable bottle cannot toggle")
	var rig = main.get_node("AnchorCamera")
	rig.body.global_position = bottle.global_position + Vector3(0, -bottle.global_position.y, 0.8)
	await get_tree().physics_frame
	await get_tree().process_frame
	store.take(bottle)
	expect(main.drink_carry.item == bottle, "Small bottle can be picked up")
	expect(store.deposit(), "Small bottle deposited on worktop")
	bench.add_supply(&"test_glass")
	rig.body.global_position = main.drink_carry.home_position + Vector3(0, -main.drink_carry.home_position.y, -0.70)
	await get_tree().physics_frame
	main._use_counter()
	await get_tree().process_frame
	expect(bench._active, "Real service UI opened")
	bench._positions[str(id)] = Vector2(600, 225)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_root.path_join("da090-closed.png"))
	bench.begin_drag(id, bench.get_item_position(id) + Vector2(0, 70))
	bench._angles[str(id)] = 80.0
	expect(bench.stream_info().is_empty(), "Closed bottle cannot pour")
	bench.advance_pour(0.2)
	expect(bench.get_bottle_remaining(id) == 250, "Closed bottle loses no liquid")
	bench.end_drag(false)
	bench.bottle_motion.erase(str(id))
	bench._angles[str(id)] = 0.0
	await click(bench, bench.get_bottle_cap_rect().get_center())
	expect(bench.is_bottle_capped(id), "Click alone does not remove cap")
	var pull_start := bench.get_bottle_cap_rect().get_center()
	var pull_press := InputEventMouseButton.new()
	pull_press.button_index = MOUSE_BUTTON_LEFT
	pull_press.pressed = true
	pull_press.position = bench.logical_to_screen(pull_start)
	pull_press.global_position = pull_press.position
	get_viewport().push_input(pull_press, true)
	var pull := InputEventMouseMotion.new()
	pull.position = bench.logical_to_screen(pull_start + Vector2(45, -40))
	pull.global_position = pull.position
	pull.relative = Vector2(45, -40) * bench._scale
	pull.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(pull, true)
	var pull_release := InputEventMouseButton.new()
	pull_release.button_index = MOUSE_BUTTON_LEFT
	pull_release.position = pull.position
	pull_release.global_position = pull.position
	get_viewport().push_input(pull_release, true)
	expect(bench.cap_item.motion.active and not bench.is_bottle_capped(id), "Pull gesture detaches and releases physical cap")
	var moving_start := bench.cap_item.logical_position
	bench.cap_item.advance(0.1)
	expect(not bench.cap_item.logical_position.is_equal_approx(moving_start) and bench.cap_item.motion.active, "Released cap follows continuous trajectory")
	var midflight := bench.cap_item.logical_position
	bench._focused = false
	bench._process(0.4)
	expect(bench.cap_item.logical_position == midflight, "Cap animation pauses when focus is lost")
	bench._focused = true
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_root.path_join("da091-cap-midflight.png"))
	for step in 720: bench.cap_item.advance(1.0 / 120.0)
	await get_tree().process_frame
	expect(not bench.is_bottle_capped(id) and not visual.cap.visible, "Pull removes cap in UI and world")
	expect(bench._dragging == &"", "Cap click does not start bottle drag")
	var cap_place := bench.cap_item.logical_position
	var free_place := Vector2(100, 225)
	bench.begin_drag(id, bench.get_item_position(id) + Vector2(0, 70))
	bench.drag_to(free_place + Vector2(0, 70))
	bench.end_drag()
	expect(bench.get_item_position(id).is_equal_approx(free_place), "Drop in absent bottle slot stays where released")
	expect(bench._hit_item(free_place + Vector2(0, 70)) == id, "Absent bottle does not swallow selection")
	expect(bench.cap_item.logical_position == cap_place, "Loose cap stays on table when bottle moves")
	expect(bench.get_hovered_cap_info(cap_place + Vector2(10,10)).get("id") == id, "Cap tooltip identifies its bottle")
	# Настоящий mouse drag отдельного Control, затем отпускание без закрытия бутылки.
	var cap_center := bench.logical_to_screen(bench.cap_item.logical_rect().get_center())
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = cap_center
	press.global_position = cap_center
	get_viewport().push_input(press, true)
	var move := InputEventMouseMotion.new()
	move.position = cap_center + Vector2(80, 45) * bench._scale
	move.global_position = move.position
	move.relative = move.position - cap_center
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(move, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = move.position
	release.global_position = move.position
	get_viewport().push_input(release, true)
	await get_tree().process_frame
	expect(bench.cap_item.logical_position.distance_to(cap_place) > 40, "Detached cap can be dragged and thrown independently")
	expect(not bench.is_bottle_capped(id) and not bench.cap_item.animating, "Dragging cap does not trigger return")
	bench.begin_drag(id, free_place + Vector2(0,70))
	bench.drag_to(Vector2(405, 435))
	bench.end_drag()
	expect(bench._hit_item(bench._bottle_transform(id) * Vector2(0,70)) == id, "Absent shaker does not block rotated bottle selection")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_root.path_join("da090-open.png"))
	bench.begin_drag(id, bench.get_item_position(id) + Vector2(0, 70))
	bench._angles[str(id)] = 80.0
	expect(not bench.stream_info().is_empty(), "Open bottle can pour")
	bench.advance_pour(0.2)
	expect(bench.get_bottle_remaining(id) < 250, "Open pour consumes finite stock")
	bench.end_drag(false)
	bench._angles[str(id)] = 0.0
	await click(bench, bench.get_bottle_cap_rect().get_center())
	expect(bench.cap_item.animating and not bench.is_bottle_capped(id), "Return flies toward bottle before sealing")
	await wait_cap(bench)
	expect(bench.is_bottle_capped(id) and visual.cap.visible, "Click detached cap reseals same model")
	bench.toggle_bottle_cap(id)
	await wait_cap(bench)
	var remaining := bench.get_bottle_remaining(id)
	main.get_node("NarrativeSession").close_service()
	await get_tree().process_frame
	store.take(bottle)
	expect(main.drink_carry.item == bottle and not bench.has_supply(id), "Open bottle picked up from worktop")
	expect(store.return_bottle(), "Open bottle returns to shelf")
	expect(bench.cap_item.detached and bench.get_hovered_cap_info(bench.cap_item.logical_rect().get_center()).is_empty(), "Cap remains independent while hidden UI shows no tooltip")
	expect(not visual.cap.visible and bench.get_bottle_remaining(id) == remaining, "Shelf return preserves open state and volume")
	rig.body.global_position = bottle.global_position + Vector3(0, -bottle.global_position.y, 0.8)
	await get_tree().physics_frame
	await get_tree().process_frame
	store.take(bottle)
	expect(store.deposit(), "Same open bottle returns to worktop")
	rig.body.global_position = main.drink_carry.home_position + Vector3(0, -main.drink_carry.home_position.y, -0.70)
	await get_tree().physics_frame
	await get_tree().process_frame
	main._use_counter()
	await get_tree().process_frame
	expect(not bench.is_bottle_capped(id) and bench.get_bottle_remaining(id) == remaining, "Real 2D/3D cycle preserves cap and stock")
	bench._focused = false
	expect(not bench.toggle_bottle_cap(id), "Unfocused UI cannot change cap")
	bench._focused = true
	expect(not bench.toggle_bottle_cap(&"test_soda"), "Legacy bottles not accidentally toggled")
	bench.set_active(false)
	expect(not bench.toggle_bottle_cap(id), "Hidden UI cannot toggle")
	if DisplayServer.get_name() != "headless":
		var preview := SmallBottleVisual.make_preview(self)
		preview.size = Vector2i(640, 800)
		var camera: Camera3D
		for child in preview.get_children():
			if child is Camera3D: camera = child
		camera.size = 0.26
		camera.position = Vector3(0.33, 0.18, 0.6)
		camera.look_at(Vector3.ZERO)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		preview.get_texture().get_image().save_png(capture_root.path_join("da090-model.png"))
	print("%s: small bottle, %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)
