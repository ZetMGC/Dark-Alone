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
func run() -> void:
	var catalog := DrinkMaterialCatalog.new()
	expect(catalog.load_file(DrinkWorkbench.MATERIALS), "Load current catalog")
	var portion := DrinkPreparation.new()
	expect(portion.configure(catalog, &"test_glass", &"faceted_test"), "Configure 240ml glass")
	var preview := FacetedGlassVisual.make_preview(self)
	var glass: FacetedGlassVisual = preview.get_node("GlassVisual")
	expect(glass.get_node("Glass").mesh is ArrayMesh and glass.get_node("Rim").mesh is TorusMesh, "Real hollow faceted mesh and separate rim")
	expect(glass.set_contents(portion.get_view()) and glass.contents.get_child_count() == 0, "Empty glass has no liquid")
	expect(not glass.set_contents(portion.get_view()), "Unchanged content does not rebuild or rerender")
	expect(portion.pour(&"fill_a", &"test_base", 80), "Fill glass")
	expect(glass.set_contents(portion.get_view()) and glass.contents.has_node("Layer0"), "3D liquid comes from actual portion")
	var count := glass.materials.size()
	for index in 8:
		var view := portion.get_view()
		view.layers[0].color[0] = 0.2 + index * 0.05
		glass.set_contents(view)
	expect(glass.materials.size() == count, "Replacing layers releases previous materials")
	var legacy_view := portion.get_view()
	legacy_view.erase("technique")
	legacy_view.erase("overall")
	expect(glass.set_contents(legacy_view) and glass.contents.has_node("Layer0"), "Legacy served payload without optional technique remains supported")
	glass.set_contents(portion.get_view())
	preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var folder := "res://artifacts" if OS.has_feature("editor") else "user://da091-captures"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		expect(preview.get_texture().get_image().save_png(folder.path_join("da091-glass-filled.png")) == OK, "Capture filled shared glass")
	var world = preload("res://scripts/service/drinks/world_drink.gd").new()
	world.setup(self, portion)
	add_child(world)
	expect(world.get_node("GlassVisual") is FacetedGlassVisual, "Carried portion uses same glass generator")
	world.set_held(true)
	expect(world.get_node("GlassVisual").materials.all(func(material: StandardMaterial3D) -> bool: return material.no_depth_test), "Held glass uses carried rendering")
	world.set_held(false)
	expect(world.get_node("GlassVisual").materials.all(func(material: StandardMaterial3D) -> bool: return not material.no_depth_test), "Putting down restores depth")
	var guest = load("res://scenes/characters/test_guest.tscn").instantiate()
	add_child(guest)
	guest.show_prepared(portion.get_view(), Vector3(0, 1.16, 0))
	var served := guest.get_node("ServedGlass/DrinkGlassVisual") as FacetedGlassVisual
	expect(served != null and served.contents.has_node("Layer0") and not guest.get_node("ServedGlass/Cup").visible, "Serving preserves shared geometry and real contents")
	expect(is_equal_approx(served.global_position.y, 1.16), "Shared glass bottom rests on counter")
	var shot := DrinkPreparation.new()
	shot.configure(catalog, &"test_shot", &"legacy_shot")
	shot.pour(&"fill_shot", &"test_base", 20)
	guest.show_prepared(shot.get_view(), Vector3(0, 1.16, 0))
	expect(not guest.has_node("ServedGlass/DrinkGlassVisual") and guest.get_node("ServedGlass/Cup").visible, "Later shot clears previous shared glass")
	world.queue_free()
	guest.queue_free()
	await get_tree().process_frame
	print("%s: faceted glass, %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)
