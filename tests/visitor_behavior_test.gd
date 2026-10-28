extends Node

var checks := 0
var failures := 0


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	get_tree().create_timer(40, true, false, true).timeout.connect(func() -> void: get_tree().quit(1))
	var main := preload("res://scenes/main/reasoning_demo.tscn").instantiate()
	main.preferences_enabled = false
	add_child(main)
	var behavior: VisitorBehavior = main.get_node("VisitorBehavior")
	var guest: ServiceGuest = main.get_node("DialogueTrigger")
	var model := behavior.model
	expect(behavior.state == &"arriving" and model.support_weight == 0, "Visit begins away from counter without hand support")
	# Убрать игрока с маршрута: блокировку отдельно проверяем физическим препятствием.
	main.get_node("AnchorCamera").body.global_position = Vector3(-4.8, 0, 0)
	Engine.time_scale = 5
	var captured := false
	var deadline := Time.get_ticks_msec() + 12000
	while behavior.state != &"docked" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if model.travel_distance > 3.8 and not captured:
			await capture(main, model, "walking")
			captured = true
	expect(behavior.state == &"docked", "Route reaches counter and settles: " + str(guest.global_position))
	expect(model.travel_distance > 6.0 and model.walk_speed < 0.01, "Distance-based gait stops with actual movement")
	expect(model.support_weight > 0.99, "Hand support enabled after arrival")
	Engine.time_scale = 1
	model.look_target = model.to_global(Vector3(1, 0.1, 1))
	model.attention = true
	behavior.set_physics_process(false)
	model.set_process(false)
	var dock_transform := guest.global_transform
	model.walk_speed = 0.65
	model._walking = 1
	model.support_weight = 0
	model.travel_distance = 0
	model._foot_locks.clear()
	var foot_error := 0.0
	for frame in 30:
		guest.global_position += guest.global_basis * Vector3.RIGHT * 0.0065
		model.travel_distance += 0.0065
		model._pose(0.01)
		var foot := model.to_global(model.skeleton.get_bone_global_pose(model.skeleton.find_bone("FootL")).origin)
		foot_error = maxf(foot_error, foot.distance_to(model._foot_locks["L"]))
	expect(foot_error < 0.015, "Planted foot remains at world contact point: " + str(foot_error))
	guest.global_transform = dock_transform
	model.walk_speed = 0
	model._walking = 0
	model.support_weight = 1
	model._pose(0.1)
	model.set_process(true)
	for frame in 120:
		model._pose(1.0 / 60)
	expect(model._look.x > 0.3 and model._look.x <= 0.61, "Head follows nearby player within neck limit")
	model.look_target = model.to_global(Vector3(0, 0, -3))
	for frame in 120:
		model._pose(1.0 / 60)
	expect(absf(model._look.x) < 0.01, "Head does not turn backwards")
	for kind in [&"interested", &"thoughtful", &"tense", &"disagree"]:
		model.react(kind)
		model._pose(0.3)
		expect(model.reaction == kind and model.skeleton.get_bone_global_pose(2).origin.is_finite(), "Finite authored reaction: " + str(kind))
	behavior._on_line(&"test_war_cinema_guest", &"arms_reply")
	expect(model.reaction == &"disagree", "Specific reply chooses authored reaction")
	behavior.set_physics_process(true)
	var glass: Node3D = guest.get_node("ServedGlass")
	guest.show_served("[TEST] Напиток")
	guest.show_prepared({"vessel": {"id": "test_glass", "capacity_ml": 240}, "layers": []}, glass.global_position + Vector3(0.04, -0.09, 0))
	var home := glass.global_transform
	expect(behavior._glass_home.is_equal_approx(home), "Prepared serving position overrides initial served signal")
	await get_tree().create_timer(2.4).timeout
	expect(glass.global_position.y > home.origin.y + 0.15, "Glass reaches raised hand near face")
	await capture(main, model, "sip")
	await get_tree().create_timer(2.6).timeout
	expect(glass.global_transform.is_equal_approx(home) and model.drink_weight == 0, "Glass returns exactly to original serving position")
	var previous := guest.global_position
	get_tree().paused = true
	await get_tree().create_timer(0.15, true).timeout
	expect(guest.global_position == previous, "Pause freezes visitor")
	get_tree().paused = false
	behavior.request_departure()
	expect(behavior.state == &"releasing", "Departure releases support before walking")
	Engine.time_scale = 5
	deadline = Time.get_ticks_msec() + 12000
	while behavior.state != &"absent" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	expect(behavior.state == &"absent" and not guest.visible, "Visitor follows exit route and disappears inside entrance: %s %s" % [behavior.state, guest.global_position])
	Engine.time_scale = 1
	print("%s: visitor behavior, %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func capture(main: Node, model: VisitorModel, label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.fov = 43
	var point := model.to_global(Vector3(0, -0.65, 0))
	camera.global_position = point + model.global_basis.orthonormalized() * Vector3(1.1, 0.3, 2.8)
	if label == "walking":
		camera.global_position = point + Vector3(2.6, 0.3, 1.8)
	main.get_node("DialogueTrigger/ServedGlass/Label").hide()
	camera.look_at(point)
	camera.current = true
	main.get_node("NavigationHUD/Screen").hide()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/visitor")
	get_viewport().get_texture().get_image().save_png("res://artifacts/visitor/behavior_%s.png" % label)
	camera.queue_free()
