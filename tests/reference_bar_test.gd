extends Node

var failures := 0
var checks := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	get_tree().create_timer(35, true, false, true).timeout.connect(func() -> void: get_tree().quit(1))
	var main := preload("res://scenes/main/reasoning_demo.tscn").instantiate()
	main.preferences_enabled = false
	add_child(main)
	var level: Node3D = main.get_node("BarLevel")
	expect(level is ReferenceBar, "Reference layout enabled in normal entry")
	expect(main._narrative_ready, "Narrative and workbench configured")
	var audio: EnvironmentAudio = main.get_node("Presentation/EnvironmentAudio")
	var rain: AudioStreamWAV = audio.get_node("Street").stream
	expect(rain.loop_end == 11025 * 16 and rain.data.decode_s16(rain.loop_end * 2) == rain.data.decode_s16(0), "Rain loop has matching inclusive continuation sample")
	audio.set_gain(0)
	expect(not audio.get_node("Street").playing and not audio.get_node("Furniture").playing, "Night ambience respects master mute")
	audio.set_gain(0.35)
	var steady := level.get_node("GuestFill").light_energy as float
	level.set_process(false)
	var flicker_min := 10.0
	var flicker_max := 0.0
	for step in 240:
		level._process(0.1)
		flicker_min = minf(flicker_min, level._flicker.light_energy)
		flicker_max = maxf(flicker_max, level._flicker.light_energy)
	expect(flicker_min >= 1.35 * 0.879 and flicker_max <= 1.351 and level.get_node("GuestFill").light_energy == steady, "Only distant lamp dips gently; guest lighting stays steady")
	level.set_process(true)
	var leaves: Array[String] = []
	var unwanted_table := false
	for part in level.get_node("Geometry").get_children():
		if "OpenDoor" in str(part.name) or str(part.name) == "EntranceDoor":
			leaves.append(str(part.name))
		if str(part.name).begins_with("TableTop") and part.position.x > 0 and part.position.z < 1.9:
			unwanted_table = true
	leaves.sort()
	expect(leaves == ["EntranceDoor", "KitchenFrontOpenDoor", "VestibuleFrontOpenDoor", "WCOneOpenDoor", "WCTwoOpenDoor"], "Only requested entrance, kitchen and toilet doors remain: " + str(leaves))
	expect(not unwanted_table, "Table and seating removed from passage beside counter")
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	rig.body.global_position = Vector3(-2.4, 0, 0.1)
	Engine.time_scale = 5
	var behavior: VisitorBehavior = main.get_node("VisitorBehavior")
	var deadline := Time.get_ticks_msec() + 10000
	while behavior.state != &"docked" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	expect(behavior.state == &"docked", "Guest reaches new counter: " + str(behavior.guest.global_position))
	Engine.time_scale = 1
	# Проверить проходы капсулой игрока в центрах дверей/рабочей зоны.
	var shape := CapsuleShape3D.new()
	shape.radius = 0.24
	shape.height = 1.8
	for point in [Vector3(-0.6, 0.95, 2.8), Vector3(2.2, 0.95, -1), Vector3(1.5, 0.95, -2.5), Vector3(3, 0.95, -2.5), Vector3(3, 0.95, -0.25), Vector3(3, 0.95, 1.15), Vector3(2.25, 0.95, 1.9), Vector3(-0.3, 0.95, -2.8), Vector3(1.4, 0.95, 0.8), Vector3(2.15, 0.95, 0.8)]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = point
		query.collision_mask = 1
		expect(level.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "Passable doorway/work area: " + str(point))
	var anchor := rig.get_anchor(&"back_counter")
	expect(anchor.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Workstation anchor has unit scale")
	rig.body.global_position = anchor.global_position - Vector3.UP * 1.65
	await get_tree().physics_frame
	await get_tree().physics_frame
	var focused := rig.request_move(&"back_counter")
	expect(focused, "Player can reach new workbench")
	if focused:
		await rig.anchor_reached
		expect(main.open_service_menu(), "Preparation opens at relocated workbench")
		main.get_node("NarrativeSession").close_service()
		rig.leave_focus()
	await capture(main, Vector3(-0.2, 1.65, -2.0), Vector3(-0.3, 1.25, -3.4), "workbench")
	# Интеграция нового зала с физической подачей из актуального main.
	var session: NarrativeSession = main.get_node("NarrativeSession")
	expect(session.open_service(), "Open preparation for physical delivery in reference bar")
	var bench: DrinkWorkbench = main.get_node("ServicePanel").workbench
	expect(bench.preparation.pour(&"reference_carry", &"test_base", 20) and main._stage_physical_drink(bench.preparation), "Stage physical drink at relocated work surface")
	expect(main.drink_carry.pick_up(), "Pick up staged drink in new layout")
	rig.body.global_position = Vector3(-0.2, 0, -2.0)
	await get_tree().physics_frame
	main._refresh_navigation()
	behavior.guest.interact()
	expect(session.service.served and not main.drink_carry.holding, "Guest interaction delivers carried drink and preserves motion gating")
	await get_tree().create_timer(4.9).timeout
	await capture(main, Vector3(-0.6, 1.7, 2.35), Vector3(-0.4, 1.3, -2), "entry")
	await capture(main, Vector3(2.65, 1.7, 1.6), Vector3(-2.8, 1.1, -0.5), "hall")
	await capture(main, Vector3(0.6, 1.6, 1.6), Vector3(2.1, 1.1, -1.4), "passage")
	await capture(main, Vector3(-2.3, 1.35, 0.2), Vector3(-3.4, 0.65, -1.9), "seating")
	expect(session.start_dialogue(&"test_war_cinema_guest"), "Conversation remains available in night lighting")
	await get_tree().create_timer(0.7).timeout
	await capture(main, Vector3(-0.2, 1.65, -2.0), Vector3(-0.2, 1.43, -0.45), "support_front")
	await capture(main, Vector3(-1.2, 1.5, -1.8), Vector3(-0.2, 1.32, -0.65), "support_side")
	session.cancel_dialogue()
	level.get_node("Geometry/Ceiling").hide()
	await capture(main, Vector3(0, 13, 0.01), Vector3.ZERO, "plan", true)
	behavior.request_departure()
	Engine.time_scale = 5
	deadline = Time.get_ticks_msec() + 10000
	while behavior.state != &"absent" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	expect(behavior.state == &"absent", "Guest returns through vestibule")
	Engine.time_scale = 1
	print("%s: reference bar, %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func capture(main: Node, pos: Vector3, target: Vector3, label: String, plan: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var camera := Camera3D.new()
	if label.begins_with("support_"):
		camera.fov = 42
	main.add_child(camera)
	camera.position = pos
	camera.look_at(target)
	if plan:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 12
	camera.current = true
	main.get_node("NavigationHUD/Screen").hide()
	main.get_node("DialogueTrigger/ServedGlass/Label").hide()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/reference_bar")
	get_viewport().get_texture().get_image().save_png("res://artifacts/reference_bar/%s.png" % label)
	camera.queue_free()
	main.get_node("AnchorCamera").view.make_current()
