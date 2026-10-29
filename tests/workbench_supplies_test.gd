extends Node
var failures := 0
var checks := 0
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	if "--small" in OS.get_cmdline_user_args(): get_window().size = Vector2i(960,600)
	var main = load("res://scenes/main/reasoning_demo.tscn").instantiate()
	main.visitor_behavior_enabled=false
	main.preferences_enabled=false
	main.checkpoint_enabled=false
	get_tree().root.add_child(main)
	get_tree().current_scene=main
	await get_tree().process_frame
	var bench: DrinkWorkbench = main.get_node("ServicePanel").workbench
	var store = main.supplies
	var rig = main.get_node("AnchorCamera")
	var carrier = main.drink_carry
	expect(bench.supplied.is_empty() and not bench.has_supply(&"cup"), "Real entry begins empty")
	expect(not bench.begin_drag(&"spoon", Vector2.ZERO), "Absent tool cannot be grabbed")
	rig.body.global_position=carrier.home_position + Vector3(0, -1.13, 1)
	await get_tree().physics_frame
	await get_tree().process_frame
	var drawers: Array = []
	var bottles: Array = []
	for child in store.get_children():
		if child is Area3D:
			if child.drawer: drawers.append(child)
			else: bottles.append(child)
	expect(drawers.size()==2 and bottles.size()==7, "Two drawers and seven shelf bottles")
	var drawer=drawers[0]
	rig.body.global_position=drawer.global_position + Vector3(0, -drawer.global_position.y, 0.8)
	await get_tree().physics_frame
	await get_tree().process_frame
	rig.set_process_unhandled_input(false)
	rig.view.look_at(drawer.global_position)
	await get_tree().physics_frame
	expect(main.get_node("InteractionController").get_target()==drawer, "Real ray reaches drawer front")
	drawer.interact()
	expect(drawer.opened and drawer.contents.visible, "Drawer opens")
	var items: Array=[]
	for child in drawer.contents.get_children():
		if child is Area3D: items.append(child)
	rig.view.look_at(items[0].global_position)
	await get_tree().physics_frame
	expect(main.get_node("InteractionController").get_target()==items[0], "Real ray reaches item in open drawer")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/da085-drawer.png")
	store.take(items[0])
	expect(carrier.holding and carrier.portion==null, "Supply uses single hand")
	store.take(items[1])
	expect(carrier.item==items[0], "Cannot take second item")
	expect(store.deposit() and bench.has_supply(&"cup") and not carrier.holding, "Deposit adds cup and releases hand")
	store.take(items[1])
	expect(store.deposit() and bench.supplied.has(&"test_glass"), "Second vessel can be stored without deadlock")
	store.take(bottles[0])
	expect(store.deposit() and bench.has_supply(bottles[0].supply_id), "Bottle transfers to workbench")
	rig.body.global_position=carrier.home_position + Vector3(0,-1.13,0.8)
	await get_tree().physics_frame
	await get_tree().process_frame
	main._use_counter()
	expect(main.get_node("NarrativeSession").mode==NarrativeSession.SERVICE and not rig.focus_active, "Counter opens directly into 2D")
	await get_tree().process_frame
	expect(bench.select_vessel(&"test_shot"), "Select transferred shot")
	expect(bench.preparation.pour(&"supply_test", &"test_base", 15), "Fill first vessel")
	expect(bench.select_vessel(&"test_glass") and bench.preparation.get_volume_ml()==0, "Second vessel has separate contents")
	expect(bench.select_vessel(&"test_shot") and bench.preparation.get_volume_ml()==15, "Returning to first vessel preserves contents")
	expect(not bench.has_supply(&"shaker") and bench.get_container_rect(&"shaker").end.x<0, "Absent shaker cannot receive hidden pours")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/da085-workbench.png")
	print("%s: supplies, %d checks, %d failures" % ["PASS" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(failures)
