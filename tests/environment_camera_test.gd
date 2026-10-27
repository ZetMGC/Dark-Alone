extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	create_timer(25).timeout.connect(func() -> void:
		printerr("FAIL: environment/camera timeout")
		quit(1)
	)
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	main.free_roam_enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	var rig: AnchorCamera = main.get_node("AnchorCamera")
	var hud: NavigationHUD = main.get_node("NavigationHUD")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var presentation: PresentationController = main.get_node("Presentation")
	var environment: EnvironmentAudio = presentation.get_node("EnvironmentAudio")
	var state := [session.shift.remaining, session.journal.get_entries().size(), session.service.served]
	_expect(is_equal_approx(rig.mouse_sensitivity, 0.003) and is_equal_approx(2.0 * rig.fade_seconds + rig.black_hold_seconds, 0.5), "Original comfortable baseline preserved")
	hud.get_node("%LookSensitivity").value = 0.5
	_expect(is_equal_approx(rig.mouse_sensitivity, 0.0015) and is_equal_approx(rig.keyboard_look_speed, 0.75), "Slider affects both mouse and keyboard")
	rig.reset_look()
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(100, 0)
	if DisplayServer.get_name() != "headless":
		rig._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		rig._unhandled_input(motion)
		_expect(is_equal_approx(rig.view.rotation.y, -0.15), "Actual mouse path uses selected sensitivity")
	else:
		rig.apply_look_delta(-motion.screen_relative * rig.mouse_sensitivity)
		_expect(is_equal_approx(rig.view.rotation.y, -0.15), "Configured sensitivity scales look delta; headless has no mouse capture")
	rig.release_look()
	rig.set_look_sensitivity(INF)
	_expect(is_equal_approx(rig.mouse_sensitivity, 0.0015), "Non-finite sensitivity ignored")
	rig.set_look_sensitivity(99)
	_expect(is_equal_approx(rig.mouse_sensitivity, 0.006), "Sensitivity bounded")
	hud.get_node("%TransitionDuration").value = 0.2
	_expect(is_equal_approx(2.0 * rig.fade_seconds + rig.black_hold_seconds, 0.2), "Duration label represents whole transition")
	rig.request_move(&"counter")
	var pose := rig.global_position
	rig.set_transition_duration(1.0)
	_expect(rig.is_transitioning and rig.global_position == pose and not rig.request_move(&"corner"), "Changing next duration cannot teleport or start another transition")
	await rig.anchor_reached
	_expect(rig.current_anchor_id == &"counter", "In-flight transition finishes correctly")
	rig.set_transition_duration(NAN)
	_expect(is_equal_approx(2.0 * rig.fade_seconds + rig.black_hold_seconds, 1.0), "Bad duration ignored")
	_expect(environment.get_node("Street") is AudioStreamPlayer3D and environment.get_node("Furniture") is AudioStreamPlayer3D, "Street and furniture are spatial sources")
	_expect(environment.get_node("Street").position.x > 5.0, "Distant street is at window")
	for name in ["Street", "Furniture"]:
		var sound: AudioStreamWAV = environment.get_node(name).stream
		var peak: int = 0
		for offset in range(0, sound.data.size(), 2):
			peak = maxi(peak, absi(sound.data.decode_s16(offset)))
		_expect(peak > 20 and peak < 2000, "Quiet unclipped procedural source: " + name)
		if name == "Street":
			_expect(sound.data.size() >= (sound.loop_end + 1) * 2 and sound.data.decode_s16(sound.loop_end * 2) == sound.data.decode_s16(0), "Street loop has valid continuation sample")
			var playback := sound.instantiate_playback()
			playback.start()
			var samples := playback.mix_audio(1.0, int(AudioServer.get_mix_rate() * 25.0))
			var step: float = 0.0
			for index in range(1, samples.size()):
				step = maxf(step, absf(samples[index].x - samples[index - 1].x))
			_expect(samples.size() == int(AudioServer.get_mix_rate() * 25.0) and step < 0.01, "Two real street-loop boundaries have no spike")
			playback.stop()
		else:
			_expect(sound.data.decode_s16(0) == 0 and sound.data.decode_s16(sound.data.size() - 2) == 0, "Furniture envelope starts and ends silently")
	var until: float = environment._until_creak
	session.open_menu()
	environment._process(100)
	_expect(environment._until_creak == until, "No new creaks while in menu")
	session.resume_menu()
	presentation.set_ambience_gain(0)
	_expect(not environment.get_node("Street").playing and not environment.get_node("Furniture").playing, "Master mute stops both sources")
	environment._process(100)
	_expect(environment._until_creak == until, "Mute does not queue surprise events")
	presentation.set_ambience_gain(0.35)
	environment.set_context(&"travel")
	environment.set_context(&"journal")
	_expect(not environment._active and not environment.get_node("Street").playing, "No bar sounds during travel or journal at home")
	environment.set_context(&"exploration")
	_expect(environment._active, "Bar sounds return in exploration")
	environment._until_creak = 0.01
	environment._process(0.02)
	_expect(environment._until_creak >= 18.0 and environment._until_creak <= 38.0, "Furniture reschedules sparsely after each event")
	_expect(state == [session.shift.remaining, session.journal.get_entries().size(), session.service.served], "Audio and camera settings preserve gameplay")
	rig.set_look_sensitivity(1.4)
	rig.set_transition_duration(0.7)
	main.queue_free()
	await process_frame
	main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.preferences_enabled = false
	main.free_roam_enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	rig = main.get_node("AnchorCamera")
	_expect(is_equal_approx(rig.mouse_sensitivity, 0.0042) and is_equal_approx(2.0 * rig.fade_seconds + rig.black_hold_seconds, 0.7), "Camera preferences survive scene replacement")
	main.get_node("NavigationHUD/%ResetCamera").pressed.emit()
	_expect(is_equal_approx(rig.mouse_sensitivity, 0.003) and is_equal_approx(2.0 * rig.fade_seconds + rig.black_hold_seconds, 0.5), "Reset restores initial camera values")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		if "--small" in OS.get_cmdline_user_args():
			root.size = Vector2i(960, 600)
		main.get_node("NarrativeSession").open_menu()
		var camera_hud: NavigationHUD = main.get_node("NavigationHUD")
		camera_hud.get_node("%ResetCamera").grab_focus()
		for frame in 5:
			await process_frame
		var scroll: ScrollContainer = camera_hud.get_node("Screen/Menu/Center/Content/SettingsScroll")
		scroll.ensure_control_visible(camera_hud.get_node("%ResetCamera"))
		for frame in 3:
			await process_frame
		_expect(scroll.get_global_rect().encloses(camera_hud.get_node("%TransitionDuration").get_global_rect()), "Transition slider fits visible scroll area")
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
		var suffix := "_small" if "--small" in OS.get_cmdline_user_args() else ""
		_expect(root.get_texture().get_image().save_png("res://artifacts/da048_camera" + suffix + ".png") == OK, "Camera settings preview")
	main.queue_free()
	await process_frame
	print("%s: environment and camera, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	# Дать звуковому потоку обработать stop/free перед завершением тестового процесса.
	await create_timer(0.15).timeout
	quit(0 if _failures == 0 else 1)
