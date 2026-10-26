extends Node

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _settle(panel: JournalPanel) -> void:
	await get_tree().process_frame
	while panel.is_transitioning():
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _run() -> void:
	get_tree().create_timer(25).timeout.connect(func() -> void:
		printerr("FAIL: book test timed out")
		get_tree().quit(1)
	)
	JournalPanel.motion_mode = &"full"
	_test_pagination()
	await _test_book()
	print("%s: journal book, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_pagination() -> void:
	var text := "Кириллица, слова и пустые строки.\n\n".repeat(20) + "длинноеслово".repeat(40) + "\nКонец."
	var pages := BookPaginator.paginate(text, ThemeDB.fallback_font, 19, Vector2(220, 110))
	var joined := ""
	var previous_end: int = 0
	for page in pages:
		_expect(page.start == previous_end and page.end > page.start, "Contiguous nonempty page ranges")
		joined += page.text
		previous_end = page.end
	_expect(pages.size() > 2 and joined == text, "Pagination preserves every Unicode character, spaces and newlines")
	_expect(BookPaginator.page_for_offset(pages, int(pages[1].start)) == 1, "Offset resolves next page")
	_expect(BookPaginator.page_for_offset(pages, text.length()) == pages.size() - 1, "End offset resolves final page")
	var larger := BookPaginator.paginate(text, ThemeDB.fallback_font, 19, Vector2(500, 300))
	_expect(larger.size() < pages.size(), "Page count responds to actual text area")
	_expect(BookPaginator.paginate("", ThemeDB.fallback_font, 19, Vector2(100, 100)).size() == 1, "Empty book has a safe page")


func _test_book() -> void:
	var glossary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/glossary/test_terms.json"))
	glossary.terms[0].description = "Длинная запись дневника с русским текстом. ".repeat(120)
	var dialogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogues/test_guest.json"))
	var catalog := DialogueCatalog.new()
	_expect(catalog.load_data(glossary, [dialogue]), "Book fixture accepted without changing JSON files")
	var session := NarrativeSession.new()
	var panel := (load("res://scenes/ui/journal_panel.tscn") as PackedScene).instantiate() as JournalPanel
	var speech := (load("res://scenes/ui/dialogue_panel.tscn") as PackedScene).instantiate() as DialoguePanel
	var summary := (load("res://scenes/ui/shift_summary_panel.tscn") as PackedScene).instantiate() as ShiftSummaryPanel
	var hud := (load("res://scenes/ui/navigation_hud.tscn") as PackedScene).instantiate() as NavigationHUD
	for node in [speech, panel, summary, hud, session]:
		get_tree().root.add_child(node)
	session.configure(catalog, speech, panel)
	session.configure_shift(2, summary)
	panel.configure_controls(hud)
	session.start_dialogue(&"test_guest_intro")
	session.choose_for_node(&"test_guest_intro", &"opening", &"ask_more")
	_expect(session.journal.get_unread_count() == 2, "Dialogue grants unread entries")
	session.open_journal()
	_expect(panel.is_transitioning() and session.mode == NarrativeSession.JOURNAL, "Opening is animated while world stays modal")
	_expect(session.journal.get_unread_count() == 2, "Opening does not mark hidden text read")
	session.request_close_journal()
	await _settle(panel)
	_expect(session.mode == NarrativeSession.DIALOGUE and session.journal.get_unread_count() == 2, "Closing during opening cancels read and returns safely")
	session.open_journal()
	await _settle(panel)
	_expect(session.journal.get_unread_count() == 1 and panel.get_page_count() > 2, "Visible opened entry marked read, long record paginated")
	var id := session.journal.selected_term_id
	_expect(panel.request_page(1) and not panel.request_page(1), "Rapid repeat rejected during turn")
	_expect(session.journal.get_entry(id).reading_offset == 0 and not session.select_journal_entry(&"test_marker"), "Pending turn does not change data and blocks stale commands")
	await get_tree().create_timer(0.1).timeout
	session.open_menu()
	var paused: float = panel.get_node("%Leaf").turn_amount
	await get_tree().create_timer(0.15).timeout
	_expect(is_equal_approx(panel.get_node("%Leaf").turn_amount, paused), "Menu pauses physical leaf")
	session.resume_menu()
	await _settle(panel)
	var offset: int = session.journal.get_entry(id).reading_offset
	_expect(panel.get_page_index() == 1 and offset > 0, "Turn commits reading position only once")
	panel.request_page(1)
	await get_tree().create_timer(0.04).timeout
	session.request_close_journal()
	await _settle(panel)
	_expect(session.mode == NarrativeSession.DIALOGUE and session.journal.get_entry(id).reading_offset == offset, "Close cancels uncommitted page turn")
	session.open_journal()
	await _settle(panel)
	_expect(panel.get_page_index() == 1, "Reopening restores page from stable character offset")
	panel.get_node("%Index").item_selected.emit(1)
	_expect(session.journal.selected_term_id == id, "Entry selection waits for leaf completion")
	await _settle(panel)
	_expect(session.journal.selected_term_id == &"test_marker" and session.journal.get_unread_count() == 0, "New entry selection commits after animation")
	session.select_journal_entry(id)
	await get_tree().process_frame
	await get_tree().process_frame
	var old_offset: int = session.journal.get_entry(id).reading_offset
	panel.get_node("%Card").offset_right -= 140
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(session.journal.get_entry(id).reading_offset == old_offset, "Layout changes do not rewrite reading progress")
	panel.set_motion_mode(&"reduced")
	panel.request_page(1)
	await _settle(panel)
	_expect(not panel.is_transitioning(), "Reduced animation completes")
	panel.request_page(-1)
	session.open_menu()
	hud.get_node("%BookMotion").select(2)
	hud.get_node("%BookMotion").item_selected.emit(2)
	session.resume_menu()
	await _settle(panel)
	_expect(JournalPanel.motion_mode == &"off" and not panel.is_transitioning(), "Disabling motion while paused settles action once on resume")
	var before: int = panel.get_page_index()
	panel.request_page(1)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not panel.is_transitioning() and panel.get_page_index() == before + 1, "Off mode turns instantly")
	_expect(not panel.set_motion_mode(&"bad"), "Unknown motion mode rejected")
	panel.set_page_volume(0)
	await get_tree().create_timer(0.08).timeout
	_expect(not panel.get_node("PageSound").playing and JournalPanel.page_volume == 0, "Zero volume stops page sound")
	panel.set_page_volume(INF)
	_expect(JournalPanel.page_volume == 0, "Invalid volume ignored")
	var sound: AudioStreamWAV = panel.get_node("PageSound").stream
	_expect(sound.data.size() == 7056 and sound.mix_rate == 22050, "Own short page rustle format")
	_expect(session.shift.remaining == 2 and session.runner.current_node_id == &"explanation", "Book actions preserve time and dialogue")
	_expect(not session.journal.set_reading_offset(id, -1) and not session.journal.set_reading_offset(id, 999999), "Bad reading offsets cannot corrupt record")
	session.request_close_journal()
	_expect(session.mode == NarrativeSession.DIALOGUE, "Off mode closes synchronously")
	JournalPanel.motion_mode = &"full"
	JournalPanel.page_volume = 0.35
	for node in [speech, panel, summary, hud, session]:
		node.queue_free()
	await get_tree().process_frame
