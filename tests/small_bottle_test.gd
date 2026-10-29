extends Node
var checks := 0
var failures := 0
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
func run() -> void:
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
		get_viewport().get_texture().get_image().save_png("res://artifacts/da090-closed.png")
	bench.begin_drag(id, bench.get_item_position(id) + Vector2(0, 70))
	bench._angles[str(id)] = 80.0
	expect(bench.stream_info().is_empty(), "Closed bottle cannot pour")
	bench.advance_pour(0.2)
	expect(bench.get_bottle_remaining(id) == 250, "Closed bottle loses no liquid")
	bench.end_drag(false)
	bench._angles[str(id)] = 0.0
	await click(bench, bench.get_bottle_cap_rect().get_center())
	expect(not bench.is_bottle_capped(id) and not visual.cap.visible, "Mouse click removes cap in UI and world")
	expect(bench._dragging == &"", "Cap click does not start bottle drag")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/da090-open.png")
	bench.begin_drag(id, bench.get_item_position(id) + Vector2(0, 70))
	bench._angles[str(id)] = 80.0
	expect(not bench.stream_info().is_empty(), "Open bottle can pour")
	bench.advance_pour(0.2)
	expect(bench.get_bottle_remaining(id) < 250, "Open pour consumes finite stock")
	bench.end_drag(false)
	bench._angles[str(id)] = 0.0
	await click(bench, bench.get_bottle_cap_rect().get_center())
	expect(bench.is_bottle_capped(id) and visual.cap.visible, "Click detached cap reseals same model")
	bench.toggle_bottle_cap(id)
	var remaining := bench.get_bottle_remaining(id)
	main.get_node("NarrativeSession").close_service()
	await get_tree().process_frame
	store.take(bottle)
	expect(main.drink_carry.item == bottle and not bench.has_supply(id), "Open bottle picked up from worktop")
	expect(store.return_bottle(), "Open bottle returns to shelf")
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
		preview.get_texture().get_image().save_png("res://artifacts/da090-model.png")
	print("%s: small bottle, %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)
