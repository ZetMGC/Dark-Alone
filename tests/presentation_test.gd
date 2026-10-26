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
	JournalPanel.motion_mode = &"off"
	create_timer(20).timeout.connect(func() -> void:
		printerr("FAIL: presentation test timed out")
		quit(1)
	)
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.free_roam_enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	var presentation := main.get_node("Presentation") as PresentationController
	var hud := main.get_node("NavigationHUD") as NavigationHUD
	var rig := main.get_node("AnchorCamera") as AnchorCamera
	var session := main.get_node("NarrativeSession") as NarrativeSession
	var state_before := [session.shift.remaining, session.service.served, session.journal.get_entries().size(), rig.current_anchor_id]
	_expect(presentation.layer < hud.layer and presentation.get_node("Screen").mouse_filter == Control.MOUSE_FILTER_IGNORE, "Effect stays below UI and does not intercept input")
	_expect(presentation.is_retro_enabled(), "Retro on by default")
	_expect(presentation.get_image_detail() == &"adaptive", "World detail follows physical pixels by default")
	var material: ShaderMaterial = presentation.get_node("Screen").material
	_expect(material.get_shader_parameter("virtual_height") == 0.0 and material.get_shader_parameter("pixel_block") == 2.0, "Adaptive effect does not cap image at 360 lines")
	_expect(not presentation.set_image_detail(&"bad") and presentation.get_image_detail() == &"adaptive", "Invalid detail cannot change preference")
	_expect(ProjectSettings.get_setting("gui/theme/default_font_multichannel_signed_distance_field", false), "Default UI and world font use scalable distance fields")
	var book_font: SystemFont = (load("res://scenes/ui/book_theme.tres") as Theme).default_font
	_expect(book_font.multichannel_signed_distance_field, "Custom Cyrillic book font also scales sharply")
	session.open_menu()
	hud.get_node("%ImageDetail").item_selected.emit(1)
	_expect(presentation.get_image_detail() == &"native" and material.get_shader_parameter("pixel_block") == 1.0, "Menu selects full pixel detail")
	presentation.set_image_detail(&"classic")
	_expect(material.get_shader_parameter("virtual_height") == 360.0, "Classic option preserves old PS1 sampling")
	hud.get_node("%RetroCheck").button_pressed = false
	_expect(not presentation.is_retro_enabled() and not presentation.get_node("Screen").visible, "Menu disables entire effect")
	hud.get_node("%AmbienceVolume").value = 0
	_expect(presentation.get_ambience_gain() == 0 and not presentation.get_node("Ambience").playing, "Zero volume silences ambience")
	presentation.set_ambience_gain(INF)
	_expect(presentation.get_ambience_gain() == 0, "Non-finite volume ignored")
	presentation.set_ambience_gain(2.0)
	_expect(presentation.get_ambience_gain() == 1.0, "Volume bounded")
	presentation.set_ambience_gain(0.0)
	var sound: AudioStreamWAV = presentation.get_node("Ambience").stream
	_expect(sound != null and sound.mix_rate == 11025 and sound.loop_end == 44100, "Loop format and duration stable")
	_expect(sound.data.size() >= (sound.loop_end + 1) * 2, "Loop end includes a valid guard sample for WAV mixer")
	if sound.data.size() >= (sound.loop_end + 1) * 2:
		_expect(sound.data.decode_s16(sound.loop_end * 2) == sound.data.decode_s16(sound.loop_begin * 2), "Loop boundary sample matches beginning")
	# Проверить реальный ресемплер, а не только крайние отсчёты исходного PCM.
	for block_size: int in [127, 512, 1024]:
		var playback := sound.instantiate_playback()
		playback.start()
		var previous: float = 0.0
		var max_step: float = 0.0
		var frames: int = 0
		var wanted := int(AudioServer.get_mix_rate() * 12.1)
		while frames < wanted:
			var mixed := playback.mix_audio(1.0, mini(block_size, wanted - frames))
			if mixed.is_empty():
				break
			for sample in mixed:
				max_step = maxf(max_step, absf(sample.x - previous))
				previous = sample.x
			frames += mixed.size()
		playback.stop()
		_expect(frames >= wanted and max_step < 0.01, "Three real loop boundaries have no spike, block " + str(block_size))
	var peak: int = 0
	for index in range(0, sound.data.size(), 2):
		peak = maxi(peak, absi(sound.data.decode_s16(index)))
	_expect(peak > 500 and peak < 4000, "Hum non-silent and has headroom")
	_expect(state_before == [session.shift.remaining, session.service.served, session.journal.get_entries().size(), rig.current_anchor_id], "Presentation settings cannot change gameplay")
	_expect(session.mode == NarrativeSession.MENU, "Settings do not leave modal menu")
	current_scene = null
	main.queue_free()
	await process_frame
	main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.free_roam_enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	presentation = main.get_node("Presentation")
	_expect(not presentation.is_retro_enabled() and presentation.get_ambience_gain() == 0, "Per-process preferences survive scene replacement")
	_expect(not main.get_node("NavigationHUD/%RetroCheck").button_pressed and main.get_node("NavigationHUD/%AmbienceVolume").value == 0, "Controls reflect retained preferences")
	_expect(presentation.get_image_detail() == &"classic" and main.get_node("NavigationHUD/%ImageDetail").selected == 2, "Image detail survives scene replacement")
	presentation.set_image_detail(&"adaptive")
	presentation.set_retro_enabled(true)
	presentation.set_ambience_gain(0.35)
	main.queue_free()
	await process_frame
	print("%s: presentation, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
