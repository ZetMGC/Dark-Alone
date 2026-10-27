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
const INK_TOOLS: Array[StringName] = [&"select", &"underline", &"circle", &"erase"]


func _ready() -> void:
	%Close.pressed.connect(func() -> void: close_requested.emit())
	%Search.text_changed.connect(func(_text: String) -> void: _refresh())
	%Section.item_selected.connect(func(_index: int) -> void: _refresh())
	%Index.item_selected.connect(_select_index)
	%Previous.pressed.connect(func() -> void: request_page(-1))
	%Next.pressed.connect(func() -> void: request_page(1))
	%Description.resized.connect(_queue_pagination)
	%Description.annotation_requested.connect(_add_ink)
	%Description.erase_requested.connect(_erase_ink)
	%Description.selection_changed.connect(_word_selected)
	%InkTool.item_selected.connect(func(index: int) -> void: %Description.set_tool(INK_TOOLS[index]))
	%InkUndo.pressed.connect(func() -> void: _undo_ink())
	%InkRedo.pressed.connect(func() -> void: _undo_ink(true))
	if _rustle == null:
		_rustle = _make_rustle()
	$PageSound.stream = _rustle


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
	%Close.text = "Вернуться к разговору" if return_to_dialogue else "Вернуться в бар"
	if return_to_summary:
		%Close.text = "К итогам смены"
	if return_to_home:
		%Close.text = "Вернуться домой"
	_refresh()


func _refresh() -> void:
	if _journal == null or _rendering:
		return
	_rendering = true
	%Count.text = "Записей: %d · Новых: %d" % [_journal.get_entries().size(), _journal.get_unread_count()]
	var sections: Array[StringName] = [&"all", &"new", &"bookmarks"]
	var entries := _journal.get_filtered_entries(%Search.text, sections[%Section.selected])
	_ids.clear()
	%Index.clear()
	var selected_index: int = -1
	for entry in entries:
		var id := StringName(entry.id)
		_ids.append(id)
		var prefix := "★ " if entry.bookmarked else ""
		if not entry.read:
			prefix += "• "
		%Index.add_item(prefix + str(entry.title))
		%Index.set_item_tooltip(_ids.size() - 1, str(entry.title))
		if id == _journal.selected_term_id:
			selected_index = _ids.size() - 1
	if selected_index >= 0:
		%Index.select(selected_index)
	%Matches.text = "Найдено: %d" % entries.size()
	for connection in %Bookmark.toggled.get_connections():
		%Bookmark.toggled.disconnect(connection.callable)
	var selected := _journal.get_entry(_journal.selected_term_id)
	if selected_index < 0 and not selected.is_empty():
		%Matches.text += " · Открытая запись вне фильтра"
	%Bookmark.set_pressed_no_signal(not selected.is_empty() and selected.bookmarked)
	%BookArt.bookmarked = not selected.is_empty() and selected.bookmarked
	if selected.is_empty():
		%EntryTitle.text = "Пока нет записей"
		%Source.text = ""
		%Position.text = "Оглавление"
	else:
		%EntryTitle.text = selected.title
		%EntryTitle.tooltip_text = selected.title
		var source: Dictionary = selected.source
		%Source.text = "Источник не указан" if source.is_empty() else "Узнано в смену %d · %s" % [source.shift, source.speaker]
		%Position.text = "Запись %d / %d" % [selected.learned_order, _journal.get_entries().size()]
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
	%PagePosition.text = "Стр. %d / %d" % [_page + 1, _pages.size()]
	_update_controls()


func get_page_count() -> int:
	return _pages.size()


func _unhandled_key_input(event: InputEvent) -> void:
	if not screen.visible or get_viewport().gui_get_focus_owner() is LineEdit or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode in [KEY_Z, KEY_Y] and not is_transitioning():
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
	if _rendering or is_transitioning() or index < 0 or index >= _ids.size() or not screen.visible:
		return
	var id := _ids[index]
	if id == _journal.selected_term_id:
		return
	%Leaf.turn_direction = 1.0 if index > _ids.find(_journal.selected_term_id) else -1.0
	_play_motion(&"turn", func() -> void: entry_requested.emit(id))


func request_page(direction: int) -> bool:
	if _journal == null or is_transitioning() or not screen.visible or direction not in [-1, 1]:
		return false
	if _layout_pending:
		_paginate()
	var target := _page + direction
	if target >= 0 and target < _pages.size():
		var id := _journal.selected_term_id
		var offset := int(_pages[target].start)
		%Leaf.turn_direction = float(direction)
		_play_motion(&"turn", func() -> void: reading_position_requested.emit(id, offset))
		return true
	var index := _ids.find(_journal.selected_term_id)
	var next_index := index + direction if index >= 0 else 0
	if next_index >= 0 and next_index < _ids.size():
		_select_index(next_index)
		return true
	return false


func _update_controls() -> void:
	var blocked := is_transitioning()
	%Search.editable = not blocked
	%Section.disabled = blocked
	%Index.mouse_filter = Control.MOUSE_FILTER_IGNORE if blocked else Control.MOUSE_FILTER_STOP
	%Index.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	var selected := -1 if _journal == null else _ids.find(_journal.selected_term_id)
	%Previous.disabled = blocked or (_page <= 0 and selected <= 0)
	%Next.disabled = blocked or (_page >= _pages.size() - 1 and (_ids.is_empty() or selected >= _ids.size() - 1))
	%Bookmark.disabled = blocked or _journal == null or _journal.selected_term_id == &""
	var ink_enabled := _can_edit_ink()
	%Description.editing_enabled = ink_enabled
	%InkTool.disabled = not ink_enabled
	%InkUndo.disabled = not ink_enabled or not _journal.can_undo_annotations(_journal.selected_term_id)
	%InkRedo.disabled = not ink_enabled or not _journal.can_redo_annotations(_journal.selected_term_id)
	%BookArt.show_sketch = _journal != null and _journal.get_entries().size() <= 4


func _can_edit_ink() -> bool:
	return not is_transitioning() and not _layout_pending and screen.visible and _journal != null and _journal.selected_term_id != &"" and %Description.entry_id == _journal.selected_term_id


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
	%WordNote.text = "Выберите слово или протяните мышью по фразе."
	if word.is_empty() or _journal == null:
		return
	%WordNote.text = "«%s» · выберите инструмент пометки" % word
	for entry in _journal.get_entries():
		if str(entry.title).trim_prefix("[TEST] ").to_lower() == word.to_lower():
			%WordNote.text = "«%s»\n%s" % [word, str(entry.description)]
			return


func set_open(value: bool) -> void:
	screen.visible = value
	if not value:
		%Description.editing_enabled = false
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
	_focus_close.call_deferred()


func begin_close() -> bool:
	if is_closing():
		return false
	_play_motion(&"close", func() -> void: close_completed.emit())
	return true


func force_closed() -> void:
	_cancel_motion()
	%Description.editing_enabled = false
	_opened = false
	%BookArt.open_amount = 0.0
	screen.visible = false
	$PageSound.stop()


func reset_scroll() -> void:
	# Совместимость с DA-033: позицию теперь задаёт reading_offset, не ScrollContainer.
	pass


func _play_motion(kind: StringName, completion: Callable) -> void:
	_cancel_motion()
	_motion = kind
	_completion = completion
	_open_start = %BookArt.open_amount
	_update_controls()
	if page_volume > 0 and AudioServer.get_driver_name() != "Dummy":
		$PageSound.volume_db = linear_to_db(page_volume)
		$PageSound.play()
	if motion_mode == &"off":
		_complete_motion()
		return
	var duration := 0.34 if kind == &"turn" else 0.42 if kind == &"open" else 0.28
	if motion_mode == &"reduced":
		duration = 0.06
	_motion_frame(0.0)
	_tween = create_tween()
	_tween.tween_method(_motion_frame, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_complete_motion.bind(_motion_serial))


func _motion_frame(value: float) -> void:
	if _motion == &"open" or _motion == &"close":
		var amount := value if _motion == &"open" else 1.0 - value
		%BookArt.open_amount = lerpf(_open_start, 1.0, value) if _motion == &"open" else _open_start * (1.0 - value)
		if motion_mode == &"reduced":
			%BookArt.open_amount = 1.0
		%Card.modulate.a = clampf((amount - 0.55) / 0.45, 0.0, 1.0) if motion_mode == &"full" else amount
	else:
		%Leaf.turn_amount = value if motion_mode == &"full" else 0.0
		%Detail.modulate.a = absf(value * 2.0 - 1.0)


func _complete_motion(serial: int = -1) -> void:
	if _motion == &"" or serial >= 0 and serial != _motion_serial:
		return
	var kind := _motion
	var completion := _completion
	_motion = &""
	_completion = Callable()
	_finish_on_resume = false
	%Leaf.turn_amount = 0.0
	%Card.modulate.a = 1.0
	%Detail.modulate.a = 1.0
	%BookArt.open_amount = 0.0 if kind == &"close" else 1.0
	if kind == &"close":
		_opened = false
	_update_controls()
	if kind == &"open":
		opened.emit()
	if completion.is_valid():
		completion.call()


func _cancel_motion() -> void:
	_motion_serial += 1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_motion = &""
	_completion = Callable()
	_finish_on_resume = false
	%Leaf.turn_amount = 0.0
	%Card.modulate.a = 1.0
	%Detail.modulate.a = 1.0


func _focus_close() -> void:
	if is_inside_tree() and screen.is_visible_in_tree():
		%Close.grab_focus()


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
