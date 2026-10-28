extends "res://tests/home_target_test.gd"
## Проверка нового дома: пеший маршрут + настоящие коллизии бытовых действий.

var house: Node3D


func _walk(point: Vector3) -> void:
	var destination := home.to_global(point)
	for frame in 240:
		var offset := destination - rig.body.global_position
		offset.y = 0
		if offset.length() < 0.09:
			break
		var forward := -rig.view.global_basis.z
		var heading := Basis(Vector3.UP, atan2(-forward.x, -forward.z))
		var local := heading.inverse() * offset.normalized()
		Input.action_press("move_right", maxf(local.x, 0))
		Input.action_press("move_left", maxf(-local.x, 0))
		Input.action_press("move_back", maxf(local.z, 0))
		Input.action_press("move_forward", maxf(-local.z, 0))
		await get_tree().physics_frame
		await get_tree().process_frame
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)
	var distance := rig.body.global_position - destination
	distance.y = 0
	_expect(distance.length() < 0.16, "Actual walking route reaches " + str(point))


func _use(id: String, feet: Vector3, node_path: String) -> void:
	var part: Node3D = house.get_node(node_path)
	await _place(feet, home.to_local(part.global_position))
	_expect(home.interaction.get_target() == house.actions[id] and house.actions[id].is_available(), "Surface reachable: " + id)
	await _key(KEY_E)


func _run() -> void:
	get_tree().create_timer(85).timeout.connect(func() -> void:
		printerr("FAIL: house test timeout")
		get_tree().quit(1)
	)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(_capture)
	if "--small" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(960, 600)
	JournalPanel.motion_mode = &"off"
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var session: NarrativeSession = main.get_node("NarrativeSession")
	home = main.get_node("HomeExploration")
	rig = home.rig
	house = home.house
	for repeat in 2:
		session.start_dialogue(&"test_guest_intro")
		session.choose_for_node(&"test_guest_intro", &"opening", &"leave")
		session.finish_for_node(&"test_guest_intro", &"goodbye")
	session.go_home()
	session.finish_commute(session.commute.trip_id)
	rig.fade_seconds = 0.05
	rig.black_hold_seconds = 0
	await get_tree().physics_frame
	_expect(house != null and house.actions.size() >= 20, "Full house with household interactions is active")
	_expect(house.room_at(Vector3(-1.8, 0, 1.9)) == "Прихожая" and house.room_at(Vector3(-2, 0, -1)) == "Кухня-гостиная" and house.room_at(Vector3(1, 0, -1)) == "Спальня" and house.room_at(Vector3(-4, 0, 2)) == "Санузел", "Four distinct rooms")
	var baseline := [session.shift.remaining, session.journal.get_entries().size(), home.state.export_progress()]
	# Весь маршрут проходит настоящими шагами: ни телепорта, ни смены камер.
	for point in [Vector3(-2, 0, -0.4), Vector3(-1, 0, -0.4), Vector3(-1, 0, -2.9), Vector3(-2.8, 0, -3.1), Vector3(-1, 0, -2.9), Vector3(-1, 0, -1.4), Vector3(1.4, 0, -1.4), Vector3(1.4, 0, -2.8), Vector3(1.4, 0, -1.4), Vector3(0.4, 0, -1.4), Vector3(0.4, 0, 1.5), Vector3(-1.8, 0, 1.9), Vector3(-2.7, 0, 1.65), Vector3(-4, 0, 1.65), Vector3(-2.7, 0, 1.65)]:
		await _walk(point)
	await _place(Vector3(-1.8, 0, 1.9), Vector3(-2, 1.5, 0.4))
	await _snap("01-entry")
	await _place(Vector3(-1.1, 0, -0.4), Vector3(-3, 1.3, -3))
	await _snap("02-living-kitchen")
	await _place(Vector3(0.6, 0, 1.5), Vector3(2.2, 1.0, 1.4))
	await _snap("03-bedroom")
	await _place(Vector3(-3.6, 0, 1.8), Vector3(-4.3, 1.5, 0.9))
	await _snap("04-bathroom")
	await _use("HallSwitch", Vector3(-1.1, 0, 2.1), "HallSwitch")
	_expect(not house.switches.HallSwitch and not house.get_node("HallLight").visible, "Switch turns hall light off")
	home.object_context.refresh_context()
	await _key(KEY_E)
	_expect(house.switches.HallSwitch, "Switch turns light back on")
	await _snap("action-light")
	await _use("Fridge", Vector3(-1.1, 0, -2.9), "FridgeHinge/FridgeDoor")
	_expect(house.switches.Fridge and absf(house.get_node("FridgeHinge").rotation.y) > 1, "Fridge opens physically")
	await _use("Fridge", Vector3(-1.1, 0, -2.9), "FridgeHinge/FridgeDoor")
	_expect(not house.switches.Fridge, "Fridge can close via moved surface")
	await _use("Kettle", Vector3(-2.8, 0, -3.05), "Kettle")
	_expect(house.kettle_remaining > 0, "Kettle starts")
	session.open_menu()
	var remaining: float = house.kettle_remaining
	await get_tree().create_timer(0.15).timeout
	_expect(is_equal_approx(house.kettle_remaining, remaining) and not house.actions.Kettle.is_available(), "Pause freezes kettle and world actions")
	session.resume_menu()
	house.tick(6, true, 0)
	_expect(house.tea_ready, "Kettle becomes ready after active duration")
	await _use("Kettle", Vector3(-2.8, 0, -3.05), "Kettle")
	_expect(not house.tea_ready and not rig.focus_active, "Tea consumed without new resource or movement lock")
	await _use("Radio", Vector3(-3.3, 0, -0.05), "Radio")
	_expect(house.radio_on, "Radio enabled")
	var presentation: PresentationController = main.get_node("Presentation")
	var gain := presentation.get_ambience_gain()
	presentation.set_ambience_gain(0)
	await get_tree().process_frame
	_expect(not house.radio.playing, "Master ambience mutes house radio")
	presentation.set_ambience_gain(gain)
	await get_tree().process_frame
	_expect(house.radio.playing, "Radio follows restored master gain")
	await _use("Radio", Vector3(-3.3, 0, -0.05), "Radio")
	_expect(not house.radio_on and not house.radio.playing, "Radio off")
	await _use("Sofa", Vector3(-3.35, 0, -0.1), "SofaCushion")
	while rig.is_transitioning:
		await get_tree().process_frame
	_expect(rig.focus_active and rig.current_anchor_id == &"seat_sofa" and not home.get_node("%InspectCurrent").visible, "Sofa sits in local view with stand action")
	await _snap("05-seated")
	await _key(KEY_ESCAPE)
	_expect(not rig.focus_active, "Escape stands at same approach")
	await _use("DiningChair", Vector3(-3.25, 0, -1.65), "DiningChair")
	while rig.is_transitioning:
		await get_tree().process_frame
	_expect(rig.focus_active and rig.current_anchor_id == &"seat_diningchair", "Dining chair usable")
	await _key(KEY_ESCAPE)
	for item in [
		["Keys", Vector3(-2, 0, 2.05), "KeyTable"],
		["Coat", Vector3(-0.7, 0, 2.05), "CoatRack"],
		["DiningTable", Vector3(-4, 0, -3.3), "DiningTop"],
		["LivingWindow", Vector3(-3.3, 0, -2.8), "LivingWindow"],
		["BedroomDesk", Vector3(1.15, 0, -2.9), "BedroomDesk"],
		["Clock", Vector3(3.1, 0, -0.5), "Clock"],
		["Mirror", Vector3(-4.2, 0, 1.65), "Mirror"],
		["Shower", Vector3(-4, 0, 1.65), "ShowerTray"],
		["Toilet", Vector3(-3.7, 0, 1.65), "Toilet"],
	]:
		await _use(item[0], item[1], item[2])
		home.object_context.refresh_context()
		_expect(not home.get_node("%Inspection").visible and home.object_context.visible, "Passive inspection stays by object: " + item[0])
		_expect(not house.actions[item[0]].context_description.is_empty(), "Passive description available")
		_expect(house.actions[item[0]].get_context_actions().is_empty(), "Passive view requires no action")
		_expect(not home.close_inspection(true), "Passive view has no modal to close")
		await _snap("info-" + item[0])
	for item in [
		["Wardrobe", Vector3(2.8, 0, -2.8), "WardrobeHinge/WardrobeDoor"],
		["BathroomCabinet", Vector3(-3.65, 0, 1.8), "BathroomCabinetHinge/BathroomCabinetDoor"],
		["Sink", Vector3(-4.2, 0, 1.8), "Sink"],
		["DeskLamp", Vector3(0.8, 0, -2.9), "DeskLamp"],
		["LivingCurtain", Vector3(-3.8, 0, -3.1), "LivingCurtain"],
		["BedroomCurtain", Vector3(2.4, 0, -2.7), "BedroomCurtain"],
		["BathroomDoor", Vector3(-2.5, 0, 2.4), "BathroomDoorHandle"],
		["BedroomDoor", Vector3(0.7, 0, 2.2), "BedroomDoorHandle"],
	]:
		var before: bool = house.switches[item[0]]
		await _use(item[0], item[1], item[2])
		_expect(house.switches[item[0]] != before, "House toggle changes state: " + item[0])
	# Дверь санузла, закрытая снаружи, действительно блокирует капсулу.
	await _place(Vector3(-2.6, 0, 1.65), Vector3(-4, 1.5, 1.65))
	Input.action_press("move_forward")
	for frame in 35:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	_expect(home.to_local(rig.body.global_position).x > -3.0, "Closed bathroom door blocks physical walking")
	await _use("BathroomDoor", Vector3(-2.6, 0, 1.65), "BathroomDoor")
	await _walk(Vector3(-4, 0, 1.65))
	await _place(Vector3(-3.2, 0, 1.65), Vector3(-3.2, 1.3, 2.7))
	house.actions.BathroomDoor.interact()
	_expect(not house.switches.BathroomDoor, "Door cannot close through player capsule")
	var wave: AudioStreamWAV = house.radio.stream
	_expect(wave.data.decode_s16(0) == wave.data.decode_s16(wave.loop_end * 2), "Radio loop has valid matching guard sample")
	_expect(baseline == [session.shift.remaining, session.journal.get_entries().size(), home.state.export_progress()], "Household actions do not alter checkpoint progress or shift")
	main.queue_free()
	get_tree().current_scene = null
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	JournalPanel.motion_mode = &"full"
	print("%s: house layout, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
