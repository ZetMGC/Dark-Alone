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
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var rig: FreeRoamCamera = main.get_node("AnchorCamera")
	var panel: DialogueBubblePanel = main.get_node("DialoguePanel")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	panel.characters_per_second = 20
	rig.body.global_position = Vector3(-4.9, 0, -0.6)
	await get_tree().physics_frame
	await get_tree().process_frame
	rig.fade_seconds = 0.01
	rig.black_hold_seconds = 0
	_expect(rig.request_move(&"counter"), "Fixture takes workstation")
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
	await _key(KEY_F)
	_expect(session.runner.current_node_id == &"opening" and panel.is_line_complete() and panel.can_answer(), "First F reveals without choosing")
	await _snap("02-replies")
	var position := rig.body.global_position
	Input.action_press("move_forward")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("move_forward")
	_expect(rig.body.global_position.is_equal_approx(position), "Dialogue look does not unlock walking")
	var facing := rig.view.global_basis
	rig.apply_look_delta(Vector2(PI, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not rig.view.global_basis.is_equal_approx(facing), "Dialogue permits turning head")
	_expect(panel.edge_mode and not panel.looking_at_speaker and panel.get_node("%VoiceDirection").visible, "Behind speaker moves bubble to corner with direction")
	_expect(not panel.get_node("%VoiceReplies").visible, "Answers hidden when looking away")
	await _key(KEY_2)
	await _key(KEY_F)
	_expect(session.runner.current_node_id == &"opening", "Away keys cannot answer")
	await _snap("03-behind")
	rig.apply_look_delta(Vector2(-PI, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(panel.can_answer() and not panel.edge_mode, "Looking back restores same line and replies")
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	_expect(panel.selected_index == 1, "Wheel selects next response")
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	_expect(panel.selected_index == 0, "Wheel selects previous response")
	await _key(KEY_F, true)
	_expect(session.runner.current_node_id == &"opening", "Held key echo ignored")
	await _key(KEY_F)
	_expect(session.runner.current_node_id == &"explanation" and not panel.is_line_complete(), "F confirms selected response and starts new text")
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
	rig.apply_look_delta(Vector2(0.3, 0))
	await get_tree().create_timer(0.15).timeout
	_expect(session.mode == NarrativeSession.MENU and text.visible_characters == count and rig.view.global_basis.is_equal_approx(paused_basis), "Menu pauses typing and camera")
	session.resume_menu()
	await _key(KEY_J)
	count = text.visible_characters
	await get_tree().create_timer(0.12).timeout
	_expect(session.mode == NarrativeSession.JOURNAL and text.visible_characters == count, "Journal pauses line")
	session.close_journal()
	_expect(text.visible_characters == count, "Return keeps reading progress")
	await _key(KEY_F)
	await _key(KEY_1)
	_expect(session.runner.current_node_id == &"goodbye", "Number directly chooses available reply")
	await _key(KEY_F)
	_expect(session.runner.active, "Terminal first F only reveals")
	await _key(KEY_F)
	_expect(not session.runner.active and session.shift.remaining == 1, "Terminal confirmed once costs one division")
	await _key(KEY_F)
	_expect(session.shift.remaining == 1, "Stale confirmation has no effect")
	main.start_test_dialogue()
	_expect(not panel.is_line_complete(), "Repeat dialogue starts animation afresh")
	rig.apply_look_delta(Vector2(PI, 0))
	await _key(KEY_BACKSPACE)
	_expect(not session.runner.active and session.shift.remaining == 1, "Explicit cancel has no finish cost")
	_expect((-rig.view.global_basis.z).dot(Vector3.RIGHT) > 0.99, "Cancel restores workstation view instead of locking backwards")
	main.start_test_dialogue()
	panel.set_open(false)
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
	_expect(bubble.selected_index == 1 and not bubble.submit_choice(0), "Locked answer cannot be selected")
	_expect(bubble.get_page_count() > 1 and bubble.get_page_index() == 0, "Long speech creates sequential bubbles")
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
	_expect(bubble.select_relative(-1) and bubble.selected_index == 8, "Final bubble unlocks wheel and skips locked answer")
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
