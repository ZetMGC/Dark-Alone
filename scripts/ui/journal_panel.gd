class_name JournalPanel
extends CanvasLayer
signal preferences_changed

signal close_requested
signal close_completed
signal opened
signal entry_requested(term_id: StringName)
signal bookmark_requested(term_id: StringName, value: bool)
signal reading_position_requested(term_id: StringName, offset: int)

# Только предпочтения восприятия; записи живут в Journal.
static var motion_mode: StringName = &"full"
static var page_volume: float = 0.35
static var _rustle: AudioStreamWAV

@onready var screen: Control = $Screen
var _journal: Journal
var _ids: Array[StringName] = []
var _index_start: int = 0
var _rendering: bool = false
var _pages: Array[Dictionary] = []
var _page: int = 0
var _layout_pending: bool = false
var _opened: bool = false
var _motion: StringName = &""
var _motion_serial: int = 0
var _tween: Tween
var _completion: Callable
var _finish_on_resume: bool = false
var _open_start: float = 0.0
var _motion_control: OptionButton
var _sound_control: HSlider
var _sound_label: Label
var current_section: StringName = &"words"
var preview_mode: bool = false
var _preview_viewport: SubViewport
const INK_TOOLS: Array[StringName] = [&"select", &"underline", &"circle", &"erase"]


func _ready() -> void:
	for tab in [%NotesTab, %RecipesTab, %WordsTab]:
		var paper := StyleBoxFlat.new()
		paper.bg_color = Color("b8ab86") if tab == %NotesTab else (Color("a5ad92") if tab == %RecipesTab else Color("c4b499"))
		paper.set_content_margin_all(4)
		paper.set_corner_radius_all(2)
		tab.add_theme_stylebox_override("normal", paper)
		tab.add_theme_stylebox_override("hover", paper)
		tab.add_theme_stylebox_override("pressed", paper)
		tab.add_theme_stylebox_override("disabled", paper)
	for style in ["selected", "selected_focus", "focus"]:
		%Index.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	%Close.pressed.connect(func() -> void: close_requested.emit())
	%Index.item_selected.connect(_select_index)
	%Previous.pressed.connect(func() -> void: request_page(-1))
	%Next.pressed.connect(func() -> void: request_page(1))
	%Description.resized.connect(_queue_pagination)
	%Description.annotation_requested.connect(_add_ink)
	%Description.erase_requested.connect(_erase_ink)
	%Description.selection_changed.connect(_word_selected)
	%WritingTools.tool_requested.connect(set_ink_tool)
	%NotesTab.pressed.connect(func() -> void: select_section(&"notes"))
	%RecipesTab.pressed.connect(func() -> void: select_section(&"recipes"))
	%WordsTab.pressed.connect(func() -> void: select_section(&"words"))
	%PaperPages.hint_changed.connect(func(text: String) -> void:
		%Hint.text = text
		_update_controls()
	)
	%PaperPages.navigation_changed.connect(_update_controls)
	if _rustle == null:
		_rustle = _make_rustle()
	$PageSound.stream = _rustle


func set_ink_tool(index: int) -> void:
	if index < 0 or index >= INK_TOOLS.size() or not _can_edit_ink():
		return
	%Description.set_tool(INK_TOOLS[index])
	%WritingTools.selected = index
	%WritingTools.queue_redraw()


func select_section(value: StringName) -> bool:
	if value not in [&"words", &"notes", &"recipes"] or is_transitioning() or not screen.visible:
		return false
	if not %PaperPages.finish_edit():
		return false
	_play_motion(&"turn", func() -> void:
		current_section = value
		%PaperPages.set_section(value)
		%Hint.text = "Выделить слово · карандаш — пометки · Ctrl+Z / Ctrl+Y — отмена" if value == &"words" else %PaperPages.default_hint()
		_update_controls()
		if value == &"words" and _journal != null and _journal.selected_term_id != &"":
			entry_requested.emit(_journal.selected_term_id)
	, {"section": value})
	return true


func configure_controls(hud: NavigationHUD) -> void:
	_motion_control = hud.get_node("%BookMotion")
	_sound_control = hud.get_node("%PageVolume")
	_sound_label = hud.get_node("%PageVolumeLabel")
	_motion_control.select([&"full", &"reduced", &"off"].find(motion_mode))
	_sound_control.set_value_no_signal(page_volume)
	_update_sound_label()
	_motion_control.item_selected.connect(func(index: int) -> void: set_motion_mode([&"full", &"reduced", &"off"][index]))
	_sound_control.value_changed.connect(set_page_volume)


func set_motion_mode(value: StringName) -> bool:
	if value not in [&"full", &"reduced", &"off"]:
		return false
	motion_mode = value
	if is_instance_valid(_motion_control):
		_motion_control.select([&"full", &"reduced", &"off"].find(value))
	if is_transitioning():
		if _tween != null and _tween.is_valid():
			_tween.kill()
		if screen.visible:
			_complete_motion()
		else:
			_finish_on_resume = true
	preferences_changed.emit()
	return true


func set_page_volume(value: float) -> void:
	if not is_finite(value):
		return
	page_volume = clampf(value, 0.0, 1.0)
	if page_volume == 0.0:
		$PageSound.stop()
	if is_instance_valid(_sound_control):
		_sound_control.set_value_no_signal(page_volume)
	_update_sound_label()
	preferences_changed.emit()


func _update_sound_label() -> void:
	if is_instance_valid(_sound_label):
		_sound_label.text = "Шелест страниц: %d%%" % roundi(page_volume * 100.0)


func render(journal: Journal, return_to_dialogue: bool, return_to_summary: bool = false, return_to_home: bool = false) -> void:
	if _journal != journal:
		if _journal != null and _journal.annotations_changed.is_connected(_ink_changed):
			_journal.annotations_changed.disconnect(_ink_changed)
		journal.annotations_changed.connect(_ink_changed)
	_journal = journal
	%Close.tooltip_text = "Вернуться к разговору" if return_to_dialogue else "Вернуться в бар"
	if return_to_summary:
		%Close.tooltip_text = "К итогам смены"
	if return_to_home:
		%Close.tooltip_text = "Вернуться домой"
	%PaperPages.bind(journal)
	_refresh()


func _refresh() -> void:
	if _journal == null or _rendering:
		return
	_rendering = true
	var entries := _journal.get_entries()
	_ids.clear()
	%Index.clear()
	for entry in entries:
		_ids.append(StringName(entry.id))
	_index_start = floori(float(maxi(0, _ids.find(_journal.selected_term_id))) / 8) * 8
	for index in range(_index_start, mini(entries.size(), _index_start + 8)):
		%Index.add_item(str(entries[index].title))
	var selected_index := _ids.find(_journal.selected_term_id) - _index_start
	if selected_index >= 0:
		%Index.select(selected_index)
	for connection in %Bookmark.toggled.get_connections():
		%Bookmark.toggled.disconnect(connection.callable)
	var selected := _journal.get_entry(_journal.selected_term_id)
	%Bookmark.set_pressed_no_signal(not selected.is_empty() and selected.bookmarked)
	%BookArt.bookmarked = not selected.is_empty() and selected.bookmarked
	if selected.is_empty():
		%EntryTitle.text = "Пока нет записей"
		%Source.text = ""
	else:
		%EntryTitle.text = selected.title
		%EntryTitle.tooltip_text = selected.title
		var source: Dictionary = selected.source
		%Source.text = "" if source.is_empty() else "Смена %d. Услышал от %s." % [source.shift, source.speaker]
		var id := StringName(selected.id)
		%Bookmark.toggled.connect(func(value: bool) -> void:
			if not is_transitioning():
				bookmark_requested.emit(id, value)
		)
	_rendering = false
	_queue_pagination()
	_update_controls()


func _queue_pagination() -> void:
	if not _layout_pending:
		_layout_pending = true
		_update_controls()
		_paginate.call_deferred()


func _paginate() -> void:
	if not _layout_pending:
		return
	_layout_pending = false
	if _journal == null or %Description.size.x < 40 or %Description.size.y < 20:
		return
	if _motion == &"turn":
		_cancel_motion()
	var entry := _journal.get_entry(_journal.selected_term_id)
	var text := "Новые слова из разговоров появятся здесь." if entry.is_empty() else str(entry.description)
	var font: Font = %Description.get_theme_font("normal_font")
	var font_size: int = %Description.get_theme_font_size("normal_font_size")
	_pages = BookPaginator.paginate(text, font, font_size, %Description.size - Vector2(12, 10))
	_page = BookPaginator.page_for_offset(_pages, 0 if entry.is_empty() else int(entry.reading_offset))
	%Description.set_content(_pages[_page].text, int(_pages[_page].start), _journal.selected_term_id)
	%Description.set_marks(_journal.get_annotations(_journal.selected_term_id))
	%PagePosition.text = str(_page + 1)
	_update_controls()


func get_page_count() -> int:
	return _pages.size()


func _unhandled_key_input(event: InputEvent) -> void:
	if not screen.visible or (get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit) or not event is InputEventKey or not event.pressed or event.echo:
		return
	if current_section == &"words" and event.ctrl_pressed and event.keycode in [KEY_Z, KEY_Y] and not is_transitioning():
		_undo_ink(event.keycode == KEY_Y or event.shift_pressed)
		get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		request_page(-1 if event.keycode == KEY_PAGEUP else 1)
		get_viewport().set_input_as_handled()


func get_page_index() -> int:
	return _page


func is_transitioning() -> bool:
	return _motion != &""


func is_closing() -> bool:
	return _motion == &"close"


func _select_index(index: int) -> void:
	_select_entry_at(index + _index_start)


func _select_entry_at(index: int) -> void:
	if _rendering or is_transitioning() or index < 0 or index >= _ids.size() or not screen.visible:
		return
	var id := _ids[index]
	if id == _journal.selected_term_id:
		return
	%Leaf.turn_direction = 1.0 if index > _ids.find(_journal.selected_term_id) else -1.0
	_play_motion(&"turn", func() -> void: entry_requested.emit(id), {"section": &"words", "term": id})


func request_page(direction: int) -> bool:
	if _journal == null or is_transitioning() or not screen.visible or direction not in [-1, 1]:
		return false
	if current_section != &"words":
		if not %PaperPages.finish_edit():
			return false
		if not %PaperPages.can_request_page(direction):
			return false
		%Leaf.turn_direction = float(direction)
		_play_motion(&"turn", func() -> void:
			%PaperPages.request_page(direction)
			_update_controls()
		, %PaperPages.get_page_preview(direction))
		return true
	if _layout_pending:
		_paginate()
	var target := _page + direction
	if target >= 0 and target < _pages.size():
		var id := _journal.selected_term_id
		var offset := int(_pages[target].start)
		%Leaf.turn_direction = float(direction)
		_play_motion(&"turn", func() -> void: reading_position_requested.emit(id, offset), {"section": &"words", "term": id, "offset": offset})
		return true
	var index := _ids.find(_journal.selected_term_id)
	var next_index := index + direction if index >= 0 else 0
	if next_index >= 0 and next_index < _ids.size():
		_select_entry_at(next_index)
		return true
	return false


func _update_controls() -> void:
	var blocked := is_transitioning()
	%Index.mouse_filter = Control.MOUSE_FILTER_IGNORE if blocked else Control.MOUSE_FILTER_STOP
	%Index.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	var selected := -1 if _journal == null else _ids.find(_journal.selected_term_id)
	%Previous.disabled = blocked or (_page <= 0 and selected <= 0)
	%Next.disabled = blocked or (_page >= _pages.size() - 1 and (_ids.is_empty() or selected >= _ids.size() - 1))
	%Bookmark.disabled = blocked or _journal == null or _journal.selected_term_id == &""
	var ink_enabled := _can_edit_ink()
	%Description.editing_enabled = ink_enabled
	%WritingTools.enabled = ink_enabled
	%WritingTools.visible = current_section == &"words"
	%Card.visible = current_section == &"words"
	%Bookmark.visible = current_section == &"words"
	%PaperPages.visible = current_section != &"words"
	%PaperPages.editing_enabled = not blocked and screen.visible and current_section != &"words"
	for tab in [%NotesTab, %RecipesTab, %WordsTab]:
		tab.disabled = blocked
	if current_section != &"words":
		%Previous.disabled = blocked or not %PaperPages.can_request_page(-1)
		%Next.disabled = blocked or not %PaperPages.can_request_page(1)
	%BookArt.show_sketch = false


func _can_edit_ink() -> bool:
	return current_section == &"words" and not is_transitioning() and not _layout_pending and screen.visible and _journal != null and _journal.selected_term_id != &"" and %Description.entry_id == _journal.selected_term_id


func _add_ink(kind: StringName, start: int, end: int) -> void:
	if not _can_edit_ink():
		return
	if not _journal.add_annotation(_journal.selected_term_id, kind, start, end):
		%WordNote.text = "Такая пометка уже есть или достигнут предел 64 пометок на запись."


func _erase_ink(index: int) -> void:
	if _can_edit_ink():
		_journal.erase_annotation(_journal.selected_term_id, index)


func _undo_ink(redo: bool = false) -> void:
	if _can_edit_ink():
		_journal.undo_annotations(_journal.selected_term_id, redo)


func _ink_changed(id: StringName) -> void:
	if _journal != null and id == _journal.selected_term_id:
		%Description.set_marks(_journal.get_annotations(id))
		_update_controls()


func _word_selected(word: String) -> void:
	%WordNote.text = ""
	if word.is_empty() or _journal == null:
		return
	%WordNote.text = "«%s»" % word
	for entry in _journal.get_entries():
		if str(entry.title).trim_prefix("[TEST] ").to_lower() == word.to_lower():
			%WordNote.text = "«%s»\n%s" % [word, str(entry.description)]
			return


func set_open(value: bool) -> void:
	screen.visible = value
	if is_instance_valid(_preview_viewport):
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	if preview_mode:
		%BookArt.open_amount = 1.0
		_update_controls()
		return
	if not value:
		%Description.editing_enabled = false
		%PaperPages.editing_enabled = false
		if _tween != null and _tween.is_valid():
			_tween.pause()
		$PageSound.stop()
		return
	if _finish_on_resume:
		_complete_motion.bind(_motion_serial).call_deferred()
	elif is_transitioning() and _tween != null and _tween.is_valid():
		_tween.play()
	elif not _opened:
		_opened = true
		%BookArt.open_amount = 0.0
		_play_motion(&"open", Callable())
	_update_controls()
	_focus_close.call_deferred()


func begin_close() -> bool:
	if is_closing():
		return false
	if not %PaperPages.finish_edit():
		return false
	_play_motion(&"close", func() -> void: close_completed.emit())
	return true


func force_closed() -> void:
	_cancel_motion()
	%Description.editing_enabled = false
	%PaperPages.editing_enabled = false
	_opened = false
	%BookArt.open_amount = 0.0
	screen.visible = false
	$PageSound.stop()


func reset_scroll() -> void:
	# Совместимость с DA-033: позицию теперь задаёт reading_offset, не ScrollContainer.
	pass


func _play_motion(kind: StringName, completion: Callable, target: Dictionary = {}) -> void:
	_cancel_motion()
	_motion = kind
	_completion = completion
	_open_start = %BookArt.open_amount
	_update_controls()
	if motion_mode == &"off":
		# Шелест — отдельное предпочтение, не отключается вместе с движением.
		if page_volume > 0 and AudioServer.get_driver_name() != "Dummy":
			$PageSound.volume_db = linear_to_db(page_volume)
			$PageSound.play()
		_complete_motion()
		return
	if kind == &"turn" and motion_mode == &"full" and DisplayServer.get_name() != "headless":
		_capture_turn.call_deferred(target, _motion_serial)
	else:
		_start_motion_tween()


func _start_motion_tween() -> void:
	if page_volume > 0 and AudioServer.get_driver_name() != "Dummy":
		$PageSound.volume_db = linear_to_db(page_volume)
		$PageSound.play()
	var duration := 0.58 if _motion == &"turn" else 0.62 if _motion == &"open" else 0.48
	if motion_mode == &"reduced":
		duration = 0.06
	_motion_frame(0.0)
	_tween = create_tween()
	_tween.tween_method(_motion_frame, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_complete_motion.bind(_motion_serial))
	if not screen.visible:
		_tween.pause()


func _capture_current(serial: int) -> bool:
	return is_inside_tree() and serial == _motion_serial and _motion == &"turn" and motion_mode == &"full"


func _capture_turn(target: Dictionary, serial: int) -> void:
	# Снимок от того же дерева UI и тех же шрифтов, не ручная имитация текста.
	while _capture_current(serial) and not screen.visible:
		await get_tree().process_frame
	if not _capture_current(serial):
		return
	await RenderingServer.frame_post_draw
	if not _capture_current(serial):
		return
	var source := get_viewport().get_texture().get_image()
	if source.is_empty():
		_start_motion_tween()
		return
	%Leaf.turn_texture = ImageTexture.create_from_image(source)
	%Leaf.texture_region = Rect2(%Leaf.get_global_rect().position / screen.size, %Leaf.size / screen.size)
	var viewport := SubViewport.new()
	_preview_viewport = viewport
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.size = source.get_size()
	viewport.size_2d_override = Vector2i(screen.size)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var preview := (load("res://scenes/ui/journal_panel.tscn") as PackedScene).instantiate() as JournalPanel
	preview.preview_mode = true
	viewport.add_child(preview)
	var copy := _journal.make_visual_copy()
	if target.has("term"):
		copy.select_entry(StringName(target.term))
		if target.has("offset"):
			copy.set_reading_offset(StringName(target.term), int(target.offset))
	preview.current_section = StringName(target.get("section", current_section))
	preview.get_node("%PaperPages").set_section(preview.current_section)
	for property in ["sheet", "recipe_index", "recipe_page"]:
		preview.get_node("%PaperPages").set(property, target.get(property, %PaperPages.get(property)))
	for property in ["offset_left", "offset_top", "offset_right", "offset_bottom"]:
		preview.get_node("%Card").set(property, %Card.get(property))
	preview.render(copy, false)
	preview.set_open(true)
	await get_tree().process_frame
	await get_tree().process_frame
	while _capture_current(serial):
		await RenderingServer.frame_post_draw
		if screen.visible:
			break
	if not _capture_current(serial) or not is_instance_valid(viewport):
		return
	%Leaf.target_texture = ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free()
	_preview_viewport = null
	_start_motion_tween()


func _motion_frame(value: float) -> void:
	if _motion == &"open" or _motion == &"close":
		%BookArt.open_amount = lerpf(_open_start, 1.0, value) if _motion == &"open" else _open_start * (1.0 - value)
		%BookRoot.pivot_offset = screen.size * 0.5
		if motion_mode == &"full":
			var lift: float = 1.0 - %BookArt.open_amount
			%BookRoot.position = Vector2(0, (screen.size.y + 40) * lift)
			%BookRoot.scale = Vector2.ONE * (1.0 - 0.04 * lift)
			%BookRoot.rotation = -0.025 * lift
		else:
			%BookRoot.modulate.a = value if _motion == &"open" else 1.0 - value
	else:
		%Leaf.turn_amount = value if motion_mode == &"full" else 0.0


func _complete_motion(serial: int = -1) -> void:
	if _motion == &"" or serial >= 0 and serial != _motion_serial:
		return
	var kind := _motion
	var completion := _completion
	if is_instance_valid(_preview_viewport):
		_preview_viewport.queue_free()
		_preview_viewport = null
	var handoff: bool = kind == &"turn" and %Leaf.target_texture != null and motion_mode == &"full"
	_motion = &""
	_completion = Callable()
	_finish_on_resume = false
	%Leaf.turn_amount = 0.0
	%Leaf.hold_target = handoff
	%Leaf.queue_redraw()
	if not handoff:
		%Leaf.turn_texture = null
		%Leaf.target_texture = null
	_reset_book_pose()
	%BookArt.open_amount = 0.0 if kind == &"close" else 1.0
	if kind == &"close":
		_opened = false
	_update_controls()
	if kind == &"open":
		opened.emit()
	if completion.is_valid():
		completion.call()
	if handoff:
		_motion = &"settle"
		_update_controls()
		_finish_turn_handoff.call_deferred(_motion_serial)


func _finish_turn_handoff(serial: int) -> void:
	# Держать точное изображение до реальной пагинации/раскладки после commit.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if serial != _motion_serial or _motion != &"settle":
		return
	_motion = &""
	%Leaf.hold_target = false
	%Leaf.turn_texture = null
	%Leaf.target_texture = null
	%Leaf.queue_redraw()
	_update_controls()


func _reset_book_pose() -> void:
	%BookRoot.position = Vector2.ZERO
	%BookRoot.scale = Vector2.ONE
	%BookRoot.rotation = 0.0
	%BookRoot.modulate.a = 1.0
	%Card.modulate.a = 1.0
	%Detail.modulate.a = 1.0
	%PaperPages.modulate.a = 1.0


func _cancel_motion() -> void:
	_motion_serial += 1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if is_instance_valid(_preview_viewport):
		_preview_viewport.queue_free()
		_preview_viewport = null
	_motion = &""
	_completion = Callable()
	_finish_on_resume = false
	%Leaf.turn_amount = 0.0
	%Leaf.hold_target = false
	%Leaf.turn_texture = null
	%Leaf.target_texture = null
	_reset_book_pose()


func _focus_close() -> void:
	if is_inside_tree() and screen.is_visible_in_tree() and not get_viewport().gui_get_focus_owner() is TextEdit:
		if current_section == &"words":
			%Close.grab_focus()
		else:
			%PaperPages.grab_focus()


func _make_rustle() -> AudioStreamWAV:
	var pcm := PackedByteArray()
	const COUNT := 3528
	pcm.resize(COUNT * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 34034
	var previous: float = 0.0
	for index in COUNT:
		var noise := random.randf_range(-1.0, 1.0)
		var value := (noise - previous * 0.6) * pow(sin(PI * float(index) / COUNT), 2) * 0.075
		previous = noise
		pcm.encode_s16(index * 2, roundi(value * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	sound.data = pcm
	return sound
