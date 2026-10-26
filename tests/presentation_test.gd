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
	session.open_menu()
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
	root.add_child(main)
	current_scene = main
	await process_frame
	presentation = main.get_node("Presentation")
	_expect(not presentation.is_retro_enabled() and presentation.get_ambience_gain() == 0, "Per-process preferences survive scene replacement")
	_expect(not main.get_node("NavigationHUD/%RetroCheck").button_pressed and main.get_node("NavigationHUD/%AmbienceVolume").value == 0, "Controls reflect retained preferences")
	presentation.set_retro_enabled(true)
	presentation.set_ambience_gain(0.35)
	main.queue_free()
	await process_frame
	print("%s: presentation, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
