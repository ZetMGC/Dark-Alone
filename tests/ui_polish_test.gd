extends SceneTree
## Полировка без изменения правил: цель, уведомления, безопасный сброс и звук.

var _checks: int = 0
var _failures: int = 0
var _capture: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _save(name: String) -> void:
	if not _capture:
		return
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var suffix := "_small" if "--small" in OS.get_cmdline_user_args() else ""
	_expect(root.get_texture().get_image().save_png("res://artifacts/da046_" + name + suffix + ".png") == OK, "Capture " + name)


func _run() -> void:
	create_timer(25).timeout.connect(func() -> void:
		printerr("FAIL: UI polish timeout")
		quit(1)
	)
	_capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	if "--small" in OS.get_cmdline_user_args():
		root.size = Vector2i(960, 600)
	JournalPanel.motion_mode = &"off"
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var hud: NavigationHUD = main.get_node("NavigationHUD")
	var rig: AnchorCamera = main.get_node("AnchorCamera")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	var summary: ShiftSummaryPanel = main.get_node("ShiftSummaryPanel")
	var notice: Control = hud.get_node("%JournalNotice")
	_expect(hud.get_node("%Message").text.contains("2 — за стойку"), "Initial objective points to first action")
	_expect(not notice.visible, "No notice before knowledge")
	await _save("entry")
	rig.request_move(&"corner")
	await rig.anchor_reached
	_expect(not hud.get_node("%Message").text.contains("2 —"), "Objective does not suggest unavailable direct route")
	rig.request_move(&"entry")
	await rig.anchor_reached
	rig.request_move(&"counter")
	await rig.anchor_reached
	main.start_test_dialogue()
	await process_frame
	await process_frame
	_expect(not hud.get_node("Screen/Bottom").visible and not hud.get_node("Screen/Actions").visible, "Dialogue hides background HUD")
	_expect(notice.visible and hud.get_node("%JournalNoticeText").text.contains("Новая запись"), "First term notifies over dialogue")
	_expect(notice.mouse_filter == Control.MOUSE_FILTER_IGNORE and notice.get_parent().layer > main.get_node("DialoguePanel").layer, "Notice is above dialogue without intercepting pointer")
	var focus := root.gui_get_focus_owner()
	session.choose_for_node(&"test_guest_intro", &"opening", &"ask_more")
	await process_frame
	_expect(hud.get_node("%JournalNoticeText").text.contains("Новые записи"), "Close discoveries aggregate")
	_expect(root.gui_get_focus_owner() == focus, "Notification does not grab keyboard focus")
	var prior_notice: String = hud.get_node("%JournalNoticeText").text
	_expect(not session.journal.add_term(session.journal.get_known_term_ids()[0]) and hud.get_node("%JournalNoticeText").text == prior_notice, "Duplicate knowledge does not change notice")
	await _save("notice")
	session.open_menu()
	var remaining: float = hud._notice_seconds
	hud._process(10.0)
	_expect(not notice.visible and hud._notice_seconds == remaining, "Pause hides and preserves notification timer")
	await _save("menu")
	session.resume_menu()
	_expect(notice.visible, "Notice returns after pause")
	session.open_journal()
	_expect(not notice.visible and hud._notice_seconds == 0.0, "Opening diary clears toast")
	await _save("journal")
	session.close_journal()
	_expect(not notice.visible, "Read notice does not return")
	session.choose_for_node(&"test_guest_intro", &"explanation", &"finish")
	session.finish_for_node(&"test_guest_intro", &"goodbye")
	_expect(hud.get_node("%Message").text.begins_with("Подайте"), "Completed talk changes objective to serving")
	_expect(hud.get_node("Screen/Bottom").visible, "World HUD returns after dialogue")
	await _save("objective")
	main.open_service_menu()
	session.serve_drink(&"test_water")
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE, "Existing cycle still completes")
	summary.get_node("%Restart").pressed.emit()
	_expect(summary.is_reset_confirmation_open() and not summary.get_node("Screen/Card").visible, "Reset confirmation hides underlying controls")
	_expect(root.gui_get_focus_owner() == summary.get_node("%CancelReset"), "Safe cancel gets initial focus")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_J
	key.physical_keycode = KEY_J
	main._input(key)
	_expect(session.mode == NarrativeSession.SHIFT_COMPLETE and summary.is_reset_confirmation_open(), "J cannot leave pending confirmation")
	await _save("reset")
	summary.cancel_reset_confirmation()
	_expect(session.journal.get_entries().size() == 2 and session.shift.finished, "Cancel preserves completed state")
	summary.get_node("%ConfirmReset").pressed.emit()
	_expect(current_scene == main, "Stale confirmation is ignored")
	var presentation: PresentationController = main.get_node("Presentation")
	var player: AudioStreamPlayer = presentation.get_node("Ambience")
	presentation.set_ambience_gain(0.1)
	await create_timer(0.25).timeout
	var from_db := player.volume_db
	presentation.set_ambience_gain(0.8)
	_expect(is_equal_approx(player.volume_db, from_db), "Gain change has no immediate amplitude jump")
	await create_timer(0.25).timeout
	_expect(is_equal_approx(player.volume_db, linear_to_db(0.8)), "Ramp reaches requested gain")
	presentation.set_ambience_gain(0.0)
	await create_timer(0.25).timeout
	_expect(not player.playing and player.volume_db <= -79.0, "Mute fades to silence then stops")
	var hum: AudioStreamWAV = player.stream
	_expect(absi(hum.data.decode_s16(0) - hum.data.decode_s16(hum.data.size() - 2)) < 100, "Hum loop has no large seam")
	var book: JournalPanel = main.get_node("JournalPanel")
	var rustle: AudioStreamWAV = book.get_node("PageSound").stream
	_expect(absi(rustle.data.decode_s16(0)) <= 1 and absi(rustle.data.decode_s16(rustle.data.size() - 2)) <= 1, "Page waveform has quiet boundaries")
	presentation.set_ambience_gain(0.35)
	main.queue_free()
	await process_frame
	print("%s: UI polish, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
