extends Node
var checks := 0
var failures := 0
func expect(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + title)
func _ready() -> void:
	run.call_deferred()
func settle(body: TabletopMotion) -> void:
	for frame in 1200: body.advance(1.0 / 120.0)
func snap(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var folder := "res://artifacts" if OS.has_feature("editor") else "user://da092-captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join(name + ".png"))
func run() -> void:
	if "--small" in OS.get_cmdline_user_args(): get_window().size = Vector2i(960, 600)
	var slow := TabletopMotion.new()
	slow.release(Vector2(200, 220), 0, Vector2.ZERO, 0.8)
	expect(slow.origin().is_equal_approx(Vector2(200, 220)), "Release above table preserves exact visible pose")
	slow.advance(0.05)
	expect(slow.origin().y > 220 and slow.elevation > 0, "Bottle falls gradually toward table")
	settle(slow)
	expect(not slow.active and absf(slow.angle) < 0.01 and slow.ground.y >= 380, "Gentle drop settles upright inside table")
	for tilt in [-0.3, 0.3]:
		var rocked := TabletopMotion.new()
		rocked.release(Vector2(400,300), tilt, Vector2(300, 450), 0.43)
		settle(rocked)
		expect(absf(rocked.angle) < 0.01, "Small sway and normal placement remain upright both ways")
	var vertical := TabletopMotion.new()
	vertical.release(Vector2(400,300), 0.1, Vector2(0, 1200), 0.43)
	settle(vertical)
	expect(absf(vertical.angle) < 0.01, "Vertical gesture alone does not tip bottle")
	var light := TabletopMotion.new()
	var heavy := TabletopMotion.new()
	light.release(Vector2(400,300), 0, Vector2(750,-150), 0.18)
	heavy.release(Vector2(400,300), 0, Vector2(750,-150), 0.95)
	expect(light.velocity.length() > heavy.velocity.length(), "Same cursor gesture gives lighter bottle more inertia speed")
	var release_pose := light.pose()
	light.advance(1.0 / 120.0)
	expect(light.pose().origin.distance_to(release_pose.origin) < 20, "First flight frame has no position jump")
	settle(light)
	settle(heavy)
	expect(absf(absf(light.angle) - PI/2) < 0.01 and not light.active, "Thrown bottle settles lying")
	expect(TabletopMotion.TABLE.has_point(light.ground) and TabletopMotion.TABLE.has_point(heavy.ground), "Both masses remain on table")
	var lying_pose := light.pose()
	light.stand_up()
	expect(light.pose().is_equal_approx(lying_pose), "Starting stand animation does not teleport")
	light.advance(0.1)
	expect(absf(light.angle) > 0.1 and absf(light.angle) < PI/2, "Stand has intermediate rotated pose")
	light.advance(0.2)
	expect(absf(light.angle) < 0.01 and not light.restoring, "Stand finishes upright")
	var cap := TabletopMotion.new()
	cap.is_cap = true
	cap.half_size = Vector2(14.5,14.5)
	cap.release(Vector2(1190,200), 0, Vector2(1400,-800), 0.008)
	settle(cap)
	var cap_rect: Rect2 = cap.pose() * Rect2(-cap.half_size, cap.half_size*2)
	expect(TabletopMotion.TABLE.encloses(cap_rect) and not cap.active, "Fast cap bounces and settles wholly within table")
	var a := TabletopMotion.new()
	var b := TabletopMotion.new()
	a.release(Vector2(600,250), 0.5, Vector2(300,100), 0.5)
	b.release(Vector2(600,250), 0.5, Vector2(300,100), 0.5)
	for frame in 120: a.advance(1.0/30.0)
	for frame in 480: b.advance(1.0/120.0)
	expect(a.ground.distance_to(b.ground) < 0.2 and absf(a.angle-b.angle) < 0.002, "Simulation agrees at 30 and 120 Hz")
	var main = load("res://scenes/main/reasoning_demo.tscn").instantiate()
	main.visitor_behavior_enabled = false
	main.preferences_enabled = false
	main.checkpoint_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	var drawer_glass: Node3D
	var drawer: Node3D
	for target in main.supplies.get_children():
		if target is Area3D and target.drawer:
			for item in target.contents.get_children():
				if item is Area3D and item.supply_id == &"test_glass":
					drawer_glass = item
					drawer = target
	expect(drawer_glass != null and drawer_glass.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Drawer glass ignores cabinet nonuniform scale")
	expect(drawer_glass.get_node("GlassVisual").global_basis.get_scale().is_equal_approx(Vector3.ONE), "Visible glass proportions match model")
	var bench: DrinkWorkbench = main.get_node("ServicePanel").workbench
	bench.add_supply(SmallBottleVisual.ID)
	bench.add_supply(&"test_glass")
	main.get_node("NarrativeSession").open_service()
	bench.set_active(true)
	bench.set_process(false)
	bench._positions["cup"] = Vector2(900, 430)
	var id := SmallBottleVisual.ID
	bench.begin_drag(id, bench.get_item_position(id))
	bench.drag_to(Vector2(480,280))
	bench.advance_motion(0.016)
	bench._throw_velocity = Vector2(800, 0)
	bench._last_drag_time = Time.get_ticks_usec()
	var before_release := bench._bottle_transform(id)
	bench.end_drag()
	expect(bench._bottle_transform(id).is_equal_approx(before_release), "UI release does not snap angle or position")
	bench.advance_tabletop(0.1)
	await snap("da092-bottle-flight")
	for frame in 1000: bench.advance_tabletop(1.0/120.0)
	expect(bench.is_bottle_lying(id), "UI throw reaches lying state")
	await snap("da092-bottle-lying")
	var lying := bench._bottle_transform(id)
	var point := bench.logical_to_screen(lying * Vector2(0,90))
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = point
		click.global_position = point
		get_viewport().push_input(click, true)
	expect((bench.bottle_motion[str(id)] as TabletopMotion).restoring and bench._bottle_transform(id).is_equal_approx(lying), "Single real click starts stand without teleport")
	bench.advance_tabletop(0.1)
	expect(bench.is_bottle_lying(id) or absf(bench.get_item_angle(id)) > 1, "UI stand interpolates")
	bench.advance_tabletop(0.2)
	expect(absf(bench.get_item_angle(id)) < 0.1, "UI stand ends upright")
	var lying_body: TabletopMotion = bench.bottle_motion[str(id)]
	lying_body.angle = PI / 2
	bench._angles[str(id)] = 90.0
	bench._positions[str(id)] = bench._motion_origin(id, lying_body)
	var pickup_pose := bench._bottle_transform(id)
	expect(bench.begin_drag(id, pickup_pose * Vector2(0,85)) and bench._bottle_transform(id).is_equal_approx(pickup_pose), "Picking lying bottle begins at same position and rotation")
	bench.advance_motion(0.1)
	expect(absf(bench.get_item_angle(id)) > 1 and absf(bench.get_item_angle(id)) < 90, "Held bottle rotates upright gradually")
	bench.advance_motion(0.15)
	expect(absf(bench.get_item_angle(id)) < 0.1, "Held bottle finishes upright")
	bench.drag_to(Vector2(450,210))
	await snap("da092-held-shadow")
	bench.end_drag(false)
	bench._positions[str(id)] = Vector2(440,300)
	bench.bottle_motion.erase(str(id))
	bench._angles[str(id)] = 0.0
	bench.set_process(false)
	bench.begin_drag(id, bench.get_item_position(id))
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for step in 10: bench._gui_input(wheel)
	expect(bench.get_item_angle(id) < -60, "Wheel tilt crosses upright to the left")
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for step in 20: bench._gui_input(wheel)
	expect(bench.get_item_angle(id) > 60, "Wheel tilt crosses upright to the right")
	bench.end_drag(false)
	bench.bottle_motion.erase(str(id))
	bench._angles[str(id)] = 90.0
	bench._positions[str(id)] = Vector2(550,490)
	var volume := bench.get_bottle_remaining(id)
	bench.advance_pour(0.05)
	expect(bench.get_bottle_remaining(id) == volume, "Capped lying bottle does not leak")
	bench.toggle_bottle_cap(id)
	bench.cap_item.advance(BottleCapItem.DURATION)
	var spilled := bench.get_spilled_ml()
	for frame in 20: bench.advance_pour(0.05)
	expect(is_equal_approx(volume - bench.get_bottle_remaining(id), 18) and is_equal_approx(bench.get_spilled_ml() - spilled, 18), "Open resting bottle loses exactly the amount added to puddle")
	await snap("da093-lying-leak")
	bench._focused = false
	volume = bench.get_bottle_remaining(id)
	bench.advance_pour(0.05)
	expect(bench.get_bottle_remaining(id) == volume, "Leak pauses on focus loss")
	bench._focused = true
	bench._angles[str(id)] = -90.0
	expect(bench.resting_bottle_streams().size() == 1, "Left leaning bottle leaks too")
	bench._angles[str(id)] = 0.0
	expect(bench.resting_bottle_streams().is_empty(), "Standing bottle stops leaking")
	# Hover is harmless, release over body cannot attach, release on rotated neck can.
	bench.cap_item.press_pointer(bench.cap_item.logical_rect().get_center())
	bench.cap_item.drag_pointer(bench._bottle_transform(id) * Vector2(0, 90))
	bench.cap_item.release_pointer()
	expect(not bench.cap_item.animating and bench.cap_item.motion.active, "Cap released over body falls instead of attaching or sticking")
	bench._angles[str(id)] = -90.0
	bench.cap_item.press_pointer(bench.cap_item.logical_rect().get_center())
	bench.cap_item.drag_pointer(bench._bottle_transform(id) * Vector2(0, 12.5))
	expect(not bench.cap_item.animating and not bench.is_bottle_capped(id), "Hover over neck does not close bottle")
	bench.cap_item.release_pointer()
	expect(bench.cap_item.animating and not bench.is_bottle_capped(id), "Release at rotated neck starts closure")
	bench.cap_item.advance(BottleCapItem.DURATION / 2)
	expect(not bench.is_bottle_capped(id), "Closure is animated before sealing")
	bench.cap_item.advance(BottleCapItem.DURATION)
	expect(bench.is_bottle_capped(id) and bench.resting_bottle_streams().is_empty(), "Closed lying bottle stops leaking without standing up")
	bench._stvor_capped = false
	bench.bottle_stock.withdraw(id, bench.get_bottle_remaining(id) - 0.1)
	var last_spill := bench.get_spilled_ml()
	bench.advance_pour(0.05)
	bench.advance_pour(0.05)
	expect(bench.get_bottle_remaining(id) == 0 and is_equal_approx(bench.get_spilled_ml() - last_spill, 0.1) and bench.resting_bottle_streams().is_empty(), "Final drops conserve volume and empty bottle stops leaking")
	bench._stvor_capped = true
	bench._angles[str(id)] = 0.0
	bench._positions[str(id)] = Vector2(440,300)
	if DisplayServer.get_name() != "headless":
		var folder := "res://artifacts" if OS.has_feature("editor") else "user://da092-captures"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var visible_image := get_viewport().get_texture().get_image()
		visible_image.save_png(folder.path_join("da092-table.png"))
		var corner := Vector2i(bench.logical_to_screen(bench.get_cup_rect().position + Vector2(1,1)))
		bench._delivered = true
		bench.queue_redraw()
		await RenderingServer.frame_post_draw
		var no_glass := get_viewport().get_texture().get_image()
		expect(visible_image.get_pixelv(corner).is_equal_approx(no_glass.get_pixelv(corner)), "Composited glass corner leaves table pixel unchanged (no rectangle)")
		var texture_image := bench._glass_preview.get_texture().get_image()
		expect(texture_image.get_pixel(0,0).a == 0 and texture_image.get_pixel(247,349).a == 0, "Glass viewport corners have zero alpha")
		bench.set_active(false)
		drawer.contents.show()
		var rig = main.get_node("AnchorCamera")
		rig.set_process_unhandled_input(false)
		rig.view.global_position = drawer_glass.global_position + Vector3(0.45,0.25,0.45)
		rig.view.look_at(drawer_glass.global_position + Vector3(0, -0.025, 0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder.path_join("da092-drawer-glass.png"))
	main.queue_free()
	await get_tree().process_frame
	print("%s: tabletop physics, %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	get_tree().quit(failures)
