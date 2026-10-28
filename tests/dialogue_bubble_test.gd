extends Node

var _checks: int = 0
var _failures: int = 0
var _capture: String = ""


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _key(code: Key, echo: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		event.echo = echo
		get_viewport().push_input(event)
	await get_tree().process_frame


func _wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame


func _snap(name: String) -> void:
	if _capture.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_expect(get_viewport().get_texture().get_image().save_png(_capture.path_join(name + ".png")) == OK, "Capture " + name)


func _run() -> void:
	get_tree().create_timer(25).timeout.connect(func() -> void:
		printerr("FAIL: dialogue bubble timed out")
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
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	var panel: DialogueBubblePanel = main.get_node("DialoguePanel")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	panel.characters_per_second = 20
	rig.body.global_position = Vector3(-4.9, 0, -1.2)
	await get_tree().physics_frame
	await get_tree().process_frame
	rig.fade_seconds = 0.01
	rig.black_hold_seconds = 0
	rig.apply_look_delta(Vector2(-PI / 2, 0))
	_expect(rig.request_move(&"back_counter"), "Fixture takes workstation")
	while rig.is_transitioning:
		await get_tree().process_frame
	_expect(main.start_test_dialogue() and panel.bubble_enabled, "Default starts bubble dialogue")
	await get_tree().create_timer(0.15).timeout
	var text: RichTextLabel = panel.get_node("%VoiceText")
	_expect(text.visible_characters > 0 and text.visible_characters < text.get_total_character_count(), "Gradual Cyrillic typewriter")
	_expect(not panel.get_node("%VoiceReplies").visible and not panel.submit_choice(0), "No answers while typing")
	_expect(panel.looking_at_speaker and not panel.edge_mode, "Bubble attached above visible speaker")
	_expect(not panel.get_node("Screen/Card").visible and not panel.get_node("Screen/Shade").visible, "World visible without old modal card")
	if DisplayServer.get_name() != "headless":
		_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Dialogue captures mouse for head look")
		var before_motion := rig.view.global_basis
		var motion := InputEventMouseMotion.new()
		motion.screen_relative = Vector2(4, 0)
		get_viewport().push_input(motion)
		await get_tree().process_frame
		_expect(not rig.view.global_basis.is_equal_approx(before_motion), "Actual mouse motion reaches dialogue camera")
		rig.reset_look()
	_expect("**" not in text.get_parsed_text() and "тестовый термин" in text.get_parsed_text(), "Important markup removed from visible text")
	await _snap("01-typing")
	if DisplayServer.get_name() != "headless":
		var reveal_click := InputEventMouseButton.new()
		reveal_click.button_index = MOUSE_BUTTON_LEFT
		reveal_click.pressed = true
		get_viewport().push_input(reveal_click)
		await get_tree().process_frame
		_expect(panel.is_line_complete() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Click reveals speech without releasing camera mouse")
		var before_click_motion := rig.view.global_basis
		var click_motion := InputEventMouseMotion.new()
		click_motion.screen_relative = Vector2(5, 0)
		get_viewport().push_input(click_motion)
		await get_tree().process_frame
		_expect(not rig.view.global_basis.is_equal_approx(before_click_motion), "Mouse still turns camera after speech click")
		rig.reset_look()
		# Восстановить набор для прежней проверки E; это та же реплика.
		panel._typed = 0
		panel._reply_pointer_dismissed = false
	await _key(KEY_E)
	_expect(session.runner.current_node_id == &"opening" and panel.is_line_complete() and panel.can_answer(), "First E reveals without choosing")
	await _key(KEY_F)
	_expect(session.runner.current_node_id == &"opening", "Old F binding no longer confirms replies")
	_expect(panel.get_node("%VoiceChoices").get_child(0).text.contains("[E]"), "Selected dialogue reply shows E binding")
	if DisplayServer.get_name() != "headless":
		_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "E keeps cursor available for hovering replies")
		var background := InputEventMouseButton.new()
		background.button_index = MOUSE_BUTTON_LEFT
		background.pressed = true
		background.position = Vector2(5, 5)
		get_viewport().push_input(background, true)
		await get_tree().process_frame
		_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and session.runner.current_node_id == &"opening", "Background click resumes camera without submitting reply")
		await get_tree().process_frame
		_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Replies do not recapture mouse on next frame")
	await _snap("02-replies")
	var position := rig.body.global_position
	Input.action_press("move_forward")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("move_forward")
	_expect(rig.body.global_position.distance_to(position) > 0.1 and not rig.focus_active and session.shift.remaining == 2, "Dialogue permits walking without spending time")
	var facing := rig.view.global_basis
	var bubble_before_turn: Vector2 = panel.get_node("%VoiceBubble").position
	rig.apply_look_delta(Vector2(PI, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not rig.view.global_basis.is_equal_approx(facing), "Dialogue permits turning head")
	_expect(panel.edge_mode and not panel.looking_at_speaker and panel.get_node("%VoiceDirection").visible, "Behind speaker moves bubble to corner with direction")
	_expect(not panel.get_node("%VoiceReplies").visible, "Answers hidden when looking away")
	var voice: Control = panel.get_node("%VoiceBubble")
	var target: Vector2 = panel._position_target
	_expect(voice.position.distance_to(target) > 5 and voice.position.distance_to(bubble_before_turn) < target.distance_to(bubble_before_turn), "Turning away begins smooth travel instead of teleporting to edge")
	var direction: String = panel.get_node("%VoiceDirection").text
	for yaw in [0.025, -0.05, 0.025]:
		rig.apply_look_delta(Vector2(yaw, 0))
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(panel.get_node("%VoiceDirection").text == direction, "Rear-centre jitter preserves chosen edge")
	var distance := voice.position.distance_to(panel._position_target)
	await get_tree().create_timer(0.18).timeout
	_expect(voice.position.distance_to(panel._position_target) < distance, "Bubble eases towards edge while speech state remains intact")
	await _key(KEY_2)
	_expect(not panel.confirm(), "Away confirmation cannot answer")
	_expect(session.runner.current_node_id == &"opening", "Away keys cannot answer")
	await _snap("03-behind")
	rig.apply_look_delta(Vector2(-PI, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(panel.can_answer() and not panel.edge_mode, "Looking back restores same line and replies")
	panel._hover_choice(1)
	_expect(panel.selected_index == 1, "Hover selects next response")
	panel._hover_choice(0)
	_expect(panel.selected_index == 0, "Hover selects previous response")
	await _key(KEY_E, true)
	_expect(session.runner.current_node_id == &"opening", "Held key echo ignored")
	await _key(KEY_E)
	_expect(session.runner.current_node_id == &"explanation" and not panel.is_line_complete(), "E confirms selected response and starts new text")
	await get_tree().create_timer(0.1).timeout
	var away_count: int = text.visible_characters
	rig.apply_look_delta(Vector2(PI, 0))
	await get_tree().create_timer(0.15).timeout
	_expect(panel.edge_mode and text.visible_characters > away_count, "NPC keeps speaking while behind player")
	rig.apply_look_delta(Vector2(-PI, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	var count: int = text.visible_characters
	await _key(KEY_ESCAPE)
	var paused_basis := rig.view.global_basis
	var paused_position := rig.body.global_position
	Input.action_press("move_back")
	rig.apply_look_delta(Vector2(0.3, 0))
	await get_tree().create_timer(0.15).timeout
	_expect(session.mode == NarrativeSession.MENU and text.visible_characters == count and rig.view.global_basis.is_equal_approx(paused_basis), "Menu pauses typing and camera")
	Input.action_release("move_back")
	_expect(rig.body.global_position.is_equal_approx(paused_position), "Menu pauses walking during dialogue")
	session.resume_menu()
	await _key(KEY_J)
	count = text.visible_characters
	paused_position = rig.body.global_position
	Input.action_press("move_back")
	await get_tree().create_timer(0.12).timeout
	Input.action_release("move_back")
	_expect(rig.body.global_position.is_equal_approx(paused_position), "Journal pauses walking during dialogue")
	_expect(session.mode == NarrativeSession.JOURNAL and text.visible_characters == count, "Journal pauses line")
	session.close_journal()
	_expect(text.visible_characters == count, "Return keeps reading progress")
	await _key(KEY_E)
	panel.get_node("%VoiceChoices").get_child(0).activated.emit()
	_expect(session.runner.current_node_id == &"goodbye", "Click chooses available reply")
	await _key(KEY_E)
	_expect(session.runner.active, "Terminal first F only reveals")
	await _key(KEY_E)
	_expect(not session.runner.active and session.shift.remaining == 1, "Terminal confirmed once costs one division")
	await _key(KEY_E)
	_expect(session.shift.remaining == 1, "Stale confirmation has no effect")
	main.start_test_dialogue()
	_expect(not panel.is_line_complete(), "Repeat dialogue starts animation afresh")
	rig.apply_look_delta(Vector2(PI, 0))
	await _key(KEY_BACKSPACE)
	_expect(not session.runner.active and session.shift.remaining == 1, "Explicit cancel has no finish cost")
	_expect((-rig.view.global_basis.z).dot(Vector3.RIGHT) < -0.99 and not rig.focus_active, "Cancel preserves free walking view")
	rig.apply_look_delta(Vector2(-PI, 0))
	main.start_test_dialogue()
	panel.set_open(false)
	await _test_reasoning_replies(main, rig)
	await _test_format_and_long(main, rig)
	_test_pagination(panel)
	JournalPanel.motion_mode = &"full"
	print("%s: dialogue bubbles, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_format_and_long(main: Node, rig: FreeRoamCamera) -> void:
	var glossary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	var styled := DialogueCatalog.new()
	styled.load_data(glossary, [document])
	var plain_document: Dictionary = document.duplicate(true)
	for node in plain_document.dialogues[0].nodes:
		node.text = DialogueText.plain(node.text)
	var plain_catalog := DialogueCatalog.new()
	plain_catalog.load_data(glossary, [plain_document])
	var terms: Array = []
	var dialogues: Array = []
	for id in plain_catalog.get_term_ids():
		terms.append(plain_catalog.get_term(StringName(id)))
	for id in plain_catalog.get_dialogue_ids():
		dialogues.append(plain_catalog.get_dialogue(StringName(id)))
	var legacy_hash := JSON.stringify([terms, dialogues, HomeState.OBJECTS, HomeState.EVENTS]).sha256_text()
	_expect(CheckpointCodec.new().content_hash(styled) == legacy_hash, "Formatting alone preserves exact pre-bubble save fingerprint")
	var label := RichTextLabel.new()
	add_child(label)
	DialogueText.write(label, "[url=bad]буквально[/url] **важно**")
	_expect(label.get_parsed_text() == "[url=bad]буквально[/url] важно", "Only emphasis parsed, arbitrary BBCode stays literal")
	DialogueText.write(label, "непарные **звёзды")
	_expect(label.get_parsed_text() == "непарные **звёзды", "Unmatched emphasis stays literal")
	label.queue_free()
	document.dialogues[0].nodes[0].text = "[TEST] **Важная деталь** длинной реплики. ".repeat(45)
	document.dialogues[0].nodes[0].choices[0].required_terms = ["test_marker"]
	for index in 7:
		var choice: Dictionary = document.dialogues[0].nodes[0].choices[1].duplicate(true)
		choice.id = "long_reply_" + str(index)
		choice.text = "[TEST] Длинный вариант ответа для проверки переноса строк и прокрутки. ".repeat(3)
		document.dialogues[0].nodes[0].choices.append(choice)
	var catalog := DialogueCatalog.new()
	_expect(catalog.load_data(glossary, [document]), "Long conditional fixture valid")
	var journal := Journal.new()
	journal.configure(catalog)
	var runner := DialogueRunner.new()
	runner.configure(catalog, journal)
	runner.start(&"test_guest_intro")
	var bubble := (load("res://scenes/ui/dialogue_bubble_panel.tscn") as PackedScene).instantiate() as DialogueBubblePanel
	bubble.bubble_enabled = true
	add_child(bubble)
	bubble.configure_speaker(rig.view, main.get_node("DialogueTrigger"))
	bubble.render(runner, journal)
	bubble.set_open(true)
	bubble.reveal_text()
	await get_tree().process_frame
	_expect(bubble.selected_index == 0 and bubble.get_node("%VoiceChoices").get_child_count() == 8 and not bubble.submit_choice(0), "Locked answer hidden, visible indices start at zero before final speech page")
	_expect(bubble.get_page_count() > 1 and bubble.get_page_index() == 0, "Long speech creates sequential bubbles")
	bubble._process(20)
	_expect(bubble.get_node("%VoiceBubble").visible and bubble.get_node("%VoiceBubble").modulate.a == 1, "Earlier pages do not disappear before advancing")
	_expect(not bubble.select_relative(-1) and not bubble.can_answer(), "Earlier bubble cannot select answers")
	await _snap("05-first-page")
	var held_page := bubble.get_page_index()
	var held_text: String = bubble.get_node("%VoiceText").get_parsed_text()
	bubble.set_open(false)
	_expect(not bubble.advance_page(), "Paused bubble cannot advance")
	bubble.set_open(true)
	_expect(bubble.get_page_index() == held_page and bubble.get_node("%VoiceText").get_parsed_text() == held_text, "Pause restores the current page")
	rig.apply_look_delta(Vector2(PI, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(bubble.edge_mode and bubble.get_page_index() == held_page, "Turning away keeps the current page")
	rig.reset_look()
	var joined := ""
	var pages_checked := 0
	var known_before := journal.get_known_term_ids()
	while true:
		bubble.reveal_text()
		var speech: RichTextLabel = bubble.get_node("%VoiceText")
		joined += speech.get_parsed_text()
		await get_tree().process_frame
		_expect(speech.get_content_height() <= speech.size.y and not speech.scroll_active and not speech.get_v_scroll_bar().visible, "Bubble fits without scrollbar")
		pages_checked += 1
		if bubble.is_speech_complete():
			break
		var page := bubble.get_page_index()
		_expect(bubble.confirm() and bubble.get_page_index() == page + 1 and not bubble.is_line_complete(), "F starts next bubble with typewriter")
		_expect(not bubble.submit_choice(1), "No premature reply between bubbles")
		if page == 0:
			bubble.render(runner, journal)
			_expect(bubble.get_page_index() == 1 and not bubble.is_line_complete(), "Repeated render preserves active continuation")
	_expect(pages_checked == bubble.get_page_count() and joined == DialogueText.plain(document.dialogues[0].nodes[0].text), "All pages preserve exact text without omissions")
	_expect(runner.current_node_id == &"opening" and journal.get_known_term_ids() == known_before, "Bubble changes do not advance story or grant knowledge")
	_expect(bubble.select_relative(-1) and bubble.selected_index == 7, "Final bubble unlocks wheel and skips locked answer")
	var rect: Rect2 = bubble.get_node("%VoiceBubble").get_global_rect()
	_expect(Rect2(Vector2.ZERO, bubble.screen.size).encloses(rect), "Bubble stays within viewport")
	await _snap("04-long-conditional")
	_expect(not bubble.advance_page(), "No extra bubble after last")
	bubble.configure_speaker(rig.view, null)
	_expect(not bubble.submit_choice(1), "Missing speaker blocks reply")
	bubble.configure_speaker(rig.view, main.get_node("DialogueTrigger"))
	bubble.set_open(false)
	_expect(not bubble.submit_choice(1) and not bubble.confirm(), "Hidden panel rejects input")
	bubble.queue_free()


func _test_pagination(panel: DialogueBubblePanel) -> void:
	var text: RichTextLabel = panel.get_node("%VoiceText")
	for source in ["Короткая речь.", "**" + "ОченьДлинноеСлово".repeat(50) + "**", "Первая строка.\n\n**" + "Жирная часть. ".repeat(70) + "**\nКонец.", "Буквальные [b]теги[/b] и непарные **звёзды. ".repeat(25)]:
		var pages := SpeechPaginator.paginate(source, text.get_theme_font("normal_font"), text.get_theme_font("bold_font"), 18, Vector2(424, 112))
		var joined := ""
		var previous := 0
		for page in pages:
			_expect(page.start == previous and page.end > page.start, "Paginator has contiguous nonempty ranges")
			previous = page.end
			joined += page.text if page.literal else DialogueText.plain(page.text)
		_expect(joined == DialogueText.plain(source), "Bold, paragraphs and unbroken words roundtrip")
	_expect(DialogueText.styled_slice("до **важное слово** после", 5, 5) == "**жное **", "Bold span remains balanced across cut")


func _test_reasoning_replies(main: Node, rig: FreeRoamCamera) -> void:
	# Изолированный runner проверяет свои ответы, а не действия фонового Main.
	main.set_process_input(false)
	var catalog := DialogueCatalog.new()
	_expect(catalog.load_files("res://content/glossary/test_war_cinema_terms.json", ["res://content/dialogues/test_war_cinema_guest.json"]), "Reasoning dialogue fixture valid")
	var journal := Journal.new()
	journal.configure(catalog)
	var runner := DialogueRunner.new()
	runner.configure(catalog, journal)
	runner.start(&"test_war_cinema_guest")
	runner.choose(&"more")
	var bubble := (load("res://scenes/ui/dialogue_bubble_panel.tscn") as PackedScene).instantiate() as DialogueBubblePanel
	bubble.bubble_enabled = true
	add_child(bubble)
	bubble.configure_speaker(rig.view, main.get_node("DialogueTrigger"))
	bubble.render(runner, journal)
	bubble.set_open(true)
	while not bubble.is_speech_complete():
		bubble.reveal_text()
		if not bubble.advance_page():
			break
	await get_tree().process_frame
	_expect(bubble.get_node("%VoiceChoices").get_child_count() == 1 and bubble.selected_index == 0, "Only available fallback shown as first response")
	_expect(bubble.get_node("%VoiceChoices").get_child(0).text.contains("Не буду"), "Visible numbers have no gaps from hidden deductions")
	await _snap("06a-single-compact")
	_expect(bubble.get_node("%VoiceReplies").size.y < 58, "Single reply panel has no reserved empty row")
	_expect(bubble.get_node("%VoiceReplies").size.x < 600, "Single reply width follows text")
	var row = bubble.get_node("%VoiceChoices").get_child(0)
	_expect(row.key_label.text == "[E]" and not row.body.text.begins_with("1."), "Single choice has separate E column without redundant number")
	bubble._process(bubble.speech_hold_seconds + 0.3)
	_expect(bubble.get_node("%VoiceBubble").modulate.a > 0 and bubble.get_node("%VoiceBubble").modulate.a < 1, "Finished speech fades gradually")
	var alpha: float = bubble.get_node("%VoiceBubble").modulate.a
	bubble._window_focused = false
	bubble._process(20)
	_expect(is_equal_approx(bubble.get_node("%VoiceBubble").modulate.a, alpha), "Focus loss pauses speech fade")
	bubble._window_focused = true
	bubble._process(bubble.speech_fade_seconds + 0.1)
	_expect(not bubble.get_node("%VoiceBubble").visible and bubble.get_node("%VoiceReplies").visible and bubble.can_answer(), "Speech disappears while answers stay available")
	await _snap("06b-faded-speech-with-replies")

	journal.choose_conclusion(&"test_memories", &"test_cinema")
	journal.choose_conclusion(&"test_arsenal", &"test_props")
	bubble.render(runner, journal)
	await get_tree().process_frame
	_expect(bubble.get_node("%VoiceChoices").get_child_count() == 2 and bubble.selected_index == 1, "New deduction inserts answer while preserving selected fallback by ID")
	_expect(bubble.get_node("%VoiceChoices").get_child(0).text.contains("Ты коллекционируешь") and bubble.get_node("%VoiceChoices").get_child(1).text.contains("Не буду"), "Replies have captions without numeric hints")
	var emitted: Array = []
	bubble.choice_requested.connect(func(_dialogue: StringName, _node: StringName, id: StringName) -> void: emitted.append(id))
	await _snap("06-reasoning-replies")
	await _key(KEY_1)
	await _key(KEY_2)
	_expect(emitted.is_empty(), "Digit keys cannot submit replies")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	await _click_reply(bubble, 0)
	_expect(emitted == [&"props"], "Click submits corresponding reply")
	await _click_reply(bubble, 1)
	_expect(emitted.back() == &"leave", "Click submits fallback")
	bubble._hover_choice(0)
	await _key(KEY_E)
	_expect(bubble.selected_index == 0 and emitted.back() == &"props", "Hover and E use the same reply after conclusion")
	runner.choose(&"props")
	bubble.render(runner, journal)
	bubble.reveal_text()
	await get_tree().process_frame
	_expect(bubble.get_node("%VoiceBubble").visible and bubble.get_node("%VoiceBubble").modulate.a > 0.95, "New speech resets fade")
	_expect(not bubble.get_node("%VoiceReplies").visible and bubble.get_node("%VoiceChoices").get_child_count() == 0, "Terminal speech never leaves empty reply card")
	_expect(bubble.get_node("%VoiceHint").text.contains("E — закончить"), "Finish hint stays outside hidden answer card")
	await _snap("07-terminal-no-card")
	runner.finish()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not bubble.get_node("%VoiceReplies").visible and not bubble.get_node("%VoiceBubble").visible, "Inactive runner hides stale speech and replies even before panel is closed")
	bubble.queue_free()
	await get_tree().process_frame
	# Нетерминальная реплика с единственным пока недоступным ответом.
	var glossary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	for choice in document.dialogues[0].nodes[0].choices:
		choice.required_terms = ["test_marker"]
	catalog = DialogueCatalog.new()
	_expect(catalog.load_data(glossary, [document]), "All-locked fixture validates")
	journal = Journal.new()
	journal.configure(catalog)
	runner = DialogueRunner.new()
	runner.configure(catalog, journal)
	runner.start(&"test_guest_intro")
	bubble = (load("res://scenes/ui/dialogue_bubble_panel.tscn") as PackedScene).instantiate() as DialogueBubblePanel
	bubble.bubble_enabled = true
	add_child(bubble)
	bubble.configure_speaker(rig.view, main.get_node("DialogueTrigger"))
	bubble.render(runner, journal)
	bubble.set_open(true)
	bubble.reveal_text()
	await get_tree().process_frame
	_expect(not bubble.get_node("%VoiceReplies").visible and not bubble.select_relative(1) and not bubble.submit_choice(0), "No available reply hides card and rejects wheel/digit actions")
	journal.add_term(&"test_marker")
	bubble.render(runner, journal)
	await get_tree().process_frame
	_expect(bubble.get_node("%VoiceReplies").visible and bubble.selected_index == 0 and bubble.get_node("%VoiceChoices").get_child_count() == 2, "Answer card returns only when responses become available")
	bubble.queue_free()

func _click_reply(bubble: DialogueBubblePanel, index: int) -> void:
	var row: Control = bubble.get_node("%VoiceChoices").get_child(index)
	var point := row.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = point
		click.global_position = point
		get_viewport().push_input(click, true)
	await get_tree().process_frame
