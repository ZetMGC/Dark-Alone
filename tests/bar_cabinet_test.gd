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
func run() -> void:
	var main = load("res://scenes/main/reasoning_demo.tscn").instantiate()
	main.preferences_enabled=false; main.visitor_behavior_enabled=false; main.checkpoint_enabled=false
	get_tree().root.add_child(main)
	get_tree().current_scene=main
	await get_tree().process_frame
	var geometry = main.get_node("BarLevel/Geometry")
	var decorative := 0
	for child in geometry.get_children():
		if str(child.name).begins_with("Bottle") or str(child.name).begins_with("Neck"): decorative += 1
	expect(decorative==0, "Cabinet contains no decorative bottle copies")
	expect(geometry.get_node_or_null("CabinetCrown")!=null and geometry.get_node_or_null("CabinetFrieze")!=null, "Cabinet has crown and inset frieze")
	var rig = main.get_node("AnchorCamera")
	rig.set_process_unhandled_input(false)
	rig.body.global_position=Vector3(-0.25,0,-2.45)
	await get_tree().physics_frame
	await get_tree().process_frame
	for bottle in main.supplies.bottle_nodes.values():
		rig.view.look_at(bottle.global_position)
		await get_tree().physics_frame
		expect(bottle.is_available(), "Bottle within reach: " + str(bottle.supply_id))
		expect(main.get_node("InteractionController").get_target()==bottle, "Ray reaches bottle: " + str(bottle.supply_id))
	expect(main.supplies.bottle_nodes.size()==8, "Eight actual inventory bottles including small Stvor")
	if DisplayServer.get_name() != "headless":
		rig.view.global_position=Vector3(0.7,1.85,-1.2)
		rig.view.look_at(Vector3(-0.25,1.85,-3.65))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/da088-cabinet.png")
	print("%s: cabinet, %d checks, %d failures" % ["PASS" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(failures)
