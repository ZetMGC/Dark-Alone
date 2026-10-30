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
func capture(viewport: Viewport, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var folder := "res://artifacts" if OS.has_feature("editor") else "user://da095-captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	expect(viewport.get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "Capture " + name)
func run() -> void:
	var catalog := DrinkMaterialCatalog.new()
	catalog.load_file(DrinkWorkbench.MATERIALS)
	var portion := DrinkPreparation.new()
	expect(portion.configure(catalog, &"test_shot", &"kromka_test") and portion.get_vessel().capacity_ml == 60, "Existing shot capacity and recipe id preserved")
	var preview := FacetedGlassVisual.make_preview(self, true)
	preview.size = Vector2i(576,630)
	var shot := preview.get_node("GlassVisual") as FacetedGlassVisual
	expect(shot.is_shot and shot.maker == "КРОМКА" and shot.segments == 16, "Shot has its own brand and geometry")
	var bounds: AABB = shot.get_node("Glass").mesh.get_aabb()
	expect(is_equal_approx(bounds.size.y, 0.070) and is_equal_approx(bounds.size.x, 0.050), "Unscaled shot dimensions are 70 by 50 mm")
	expect(shot.floor_height > 0.013 and shot.get_node("ThickBase").mesh.height > 0.010, "Heavy glass base is part of geometry")
	shot.set_contents(portion.get_view())
	expect(shot.contents.get_child_count() == 0, "Empty shot has open cavity and no fake liquid")
	await capture(preview, "da095-shot-empty")
	if DisplayServer.get_name() != "headless":
		var pixels := preview.get_texture().get_image()
		expect(pixels.get_pixel(0,0).a == 0 and pixels.get_pixel(575,629).a == 0, "Shot sprite corners are transparent")
	portion.pour(&"kromka_fill", &"test_base", 30)
	shot.set_contents(portion.get_view())
	var layer := shot.contents.get_node("Layer0") as MeshInstance3D
	expect(is_equal_approx(layer.mesh.height, shot.fill_height / 2) and layer.position.y > shot.floor_height, "Liquid fill follows actual volume above thick base")
	expect(not shot.set_contents(portion.get_view()), "Unchanged shot does not rebuild")
	preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	await capture(preview, "da095-shot-filled")
	var chilled := portion.get_view()
	chilled.technique.ice_ml = 10.0
	chilled.technique.aeration = 0.5
	shot.set_contents(chilled)
	expect(shot.contents.has_node("Ice0") and shot.contents.has_node("Foam"), "Shot supports actual ice and aeration view")
	var ice: MeshInstance3D = shot.contents.get_node("Ice0")
	expect(ice.position.y + ice.mesh.size.y / 2 < shot.vessel_height, "Shot ice remains inside vessel height")
	shot.set_contents(portion.get_view())
	var world = preload("res://scripts/service/drinks/world_drink.gd").new()
	world.setup(self, portion)
	add_child(world)
	var carried: FacetedGlassVisual = world.get_node("GlassVisual")
	expect(carried.is_shot and carried.get_node("Glass").mesh.get_aabb() == bounds, "World portion and 2D preview share exact mesh dimensions")
	world.set_held(true)
	expect(carried.materials.all(func(m: StandardMaterial3D) -> bool: return m.no_depth_test), "Carried shot uses held rendering")
	world.set_held(false)
	expect(carried.materials.all(func(m: StandardMaterial3D) -> bool: return not m.no_depth_test), "Put-down restores depth testing")
	var main = load("res://scenes/main/reasoning_demo.tscn").instantiate()
	main.visitor_behavior_enabled = false
	main.preferences_enabled = false
	main.checkpoint_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	var drawer_shot: Node3D
	var drawer: Node3D
	for target in main.supplies.get_children():
		if target is Area3D and target.drawer:
			for item in target.contents.get_children():
				if item is Area3D and item.supply_id == &"test_shot":
					drawer_shot = item
					drawer = target
	expect(drawer_shot != null and drawer_shot.get_node("GlassVisual").is_shot, "Real drawer supplies shared shot model")
	expect(drawer_shot.get_node("GlassVisual").global_basis.get_scale().is_equal_approx(Vector3.ONE), "Drawer does not squash shot")
	var guest = main.get_node("DialogueTrigger")
	guest.show_prepared(portion.get_view(), Vector3(0,1.16,0))
	var served: FacetedGlassVisual = guest.get_node("ServedGlass/DrinkGlassVisual")
	expect(served.is_shot and served.contents.has_node("Layer0") and is_equal_approx(served.global_position.y,1.16), "Served shot preserves real contents and rests on counter")
	var bench: DrinkWorkbench = main.get_node("ServicePanel").workbench
	bench.add_supply(&"test_shot")
	bench.add_supply(&"test_glass")
	main.get_node("NarrativeSession").open_service()
	bench.set_active(true)
	bench.select_vessel(&"test_shot")
	bench.preparation.pour(&"bench_shot", &"test_base",30)
	bench.queue_redraw()
	expect(bench._shot_preview.get_node("GlassVisual").is_shot, "Workbench has dedicated shot viewport")
	await capture(get_viewport(), "da095-shot-workbench")
	if DisplayServer.get_name() != "headless":
		var before := get_viewport().get_texture().get_image()
		var corner := Vector2i(bench.logical_to_screen(bench.get_cup_rect().position + Vector2.ONE))
		bench._delivered = true
		bench.queue_redraw()
		await RenderingServer.frame_post_draw
		expect(before.get_pixelv(corner).is_equal_approx(get_viewport().get_texture().get_image().get_pixelv(corner)), "2D shot corner leaves background unchanged")
		bench.set_active(false)
		drawer.contents.show()
		var rig = main.get_node("AnchorCamera")
		rig.set_process_unhandled_input(false)
		rig.view.global_position = drawer_shot.global_position + Vector3(0.40,0.50,0.40)
		rig.view.look_at(drawer_shot.global_position + Vector3(0,-0.03,0))
		await capture(get_viewport(), "da095-shot-drawer")
	world.queue_free()
	main.queue_free()
	await get_tree().process_frame
	print("%s: shot glass, %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	get_tree().quit(failures)
