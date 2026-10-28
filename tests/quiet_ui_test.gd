extends SceneTree
var checks: int = 0
var failures: int = 0
var capture: String = ""
func _initialize() -> void:
	run.call_deferred()
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture)
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	root.add_child(main)
	await process_frame
	await process_frame
	var hud = main.get_node("NavigationHUD")
	hud.set_menu_visible(true)
	for dimensions in [Vector2i(960,600), Vector2i(3440,1440), Vector2i(3840,2160)]:
		root.size = dimensions
		for settings in [false, true]:
			hud.show_settings(settings)
			await process_frame
			await process_frame
			var button = hud.get_node("%SettingsBack" if settings else "%Resume")
			expect(button.size.x <= 400 and button.size.y <= 48, "Bounded menu buttons " + str(dimensions))
			var content = hud.get_node("Screen/Menu/Center/Content")
			expect(content.size.x <= 620, "Bounded content width " + str(dimensions))
			if not capture.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(capture.path_join("menu_%d_%s.png" % [dimensions.x, settings]))
	var notice = load("res://scripts/ui/notice_bubble.gd").new()
	hud.get_node("Screen").add_child(notice)
	notice.show_hint("Test", "test")
	expect(notice.visible and notice.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Passive bubble visible")
	notice._process(5)
	expect(notice.remaining == 0, "Bubble expires")
	notice._process(0)
	expect(not notice.visible, "Expired bubble hidden")
	notice.show_hint("Test", "test")
	expect(not notice.visible, "Repeated hint suppressed")
	var reticle = hud.get_node("Screen/Reticle")
	expect(reticle.text.is_empty(), "Cross removed")
	expect(not hud.get_node("%MovementHint").visible, "Bottom hint hidden")
	reticle.show()
	reticle.amount = 1.0
	main.get_node("InteractionController").set_enabled(false)
	reticle._process(0.06)
	expect(reticle.amount > 0 and reticle.amount < 1, "Reticle returns smoothly to dot")
	var bench = main.get_node("ServicePanel").workbench
	root.size = Vector2i(1280,720)
	hud.set_menu_visible(false)
	main.get_node("AnchorCamera").set_controls_enabled(false)
	main.get_node("ServicePanel").screen.show()
	bench.set_active(true)
	await process_frame
	await process_frame
	var id = StringName(bench._ids[0])
	var point = bench.get_item_position(id) + Vector2(0, 90)
	expect(not bench.get_hovered_bottle_info(point).is_empty(), "Standing bottle exposes info")
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		root.warp_mouse(bench.logical_to_screen(point))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture.path_join("bottle-hover.png"))
	expect(bench.begin_drag(id, point), "Bottle can be picked up")
	expect(bench.get_hovered_bottle_info(point).is_empty(), "Held bottle hides info immediately")
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture.path_join("bottle-held.png"))
	bench.end_drag(false)
	bench.set_active(false)
	expect(bench.get_hovered_bottle_info(point).is_empty(), "Inactive station hides info")
	print("%s: quiet UI, %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
