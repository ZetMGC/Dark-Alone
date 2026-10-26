class_name JournalPanel
extends CanvasLayer

signal close_requested
signal entry_requested(term_id: StringName)
signal bookmark_requested(term_id: StringName, value: bool)

@onready var screen: Control = $Screen
var _journal: Journal
var _ids: Array[StringName] = []
var _rendering: bool = false


func _ready() -> void:
	%Close.pressed.connect(func() -> void: close_requested.emit())
	%Search.text_changed.connect(func(_text: String) -> void: _refresh())
	%Section.item_selected.connect(func(_index: int) -> void: _refresh())
	%Index.item_selected.connect(_select_index)
	%Previous.pressed.connect(func() -> void: _step(-1))
	%Next.pressed.connect(func() -> void: _step(1))


func render(journal: Journal, return_to_dialogue: bool, return_to_summary: bool = false, return_to_home: bool = false) -> void:
	_journal = journal
	%Close.text = "Вернуться к разговору" if return_to_dialogue else "Вернуться в бар"
	if return_to_summary:
		%Close.text = "К итогам смены"
	if return_to_home:
		%Close.text = "К паузе между сменами"
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
	%Bookmark.disabled = selected.is_empty()
	%Bookmark.set_pressed_no_signal(not selected.is_empty() and selected.bookmarked)
	%Previous.disabled = selected_index <= 0
	%Next.disabled = _ids.is_empty() or selected_index >= _ids.size() - 1
	if selected.is_empty():
		%EntryTitle.text = "Пока нет записей"
		%Description.text = "Новые слова из разговоров появятся здесь."
		%Source.text = ""
		%Position.text = "0 / 0"
	else:
		%EntryTitle.text = selected.title
		%Description.text = selected.description
		var source: Dictionary = selected.source
		%Source.text = "Источник не указан" if source.is_empty() else "Узнано в смену %d\nИсточник: %s" % [source.shift, source.speaker]
		%Position.text = "Запись %d / %d" % [selected.learned_order, _journal.get_entries().size()]
		var id := StringName(selected.id)
		%Bookmark.toggled.connect(func(value: bool) -> void: bookmark_requested.emit(id, value))
	_rendering = false


func _select_index(index: int) -> void:
	if _rendering or index < 0 or index >= _ids.size():
		return
	entry_requested.emit(_ids[index])
	reset_scroll()


func _step(direction: int) -> void:
	if _journal == null:
		return
	var index := _ids.find(_journal.selected_term_id)
	var next_index := index + direction if index >= 0 else 0
	if next_index >= 0 and next_index < _ids.size():
		_select_index(next_index)


func set_open(value: bool) -> void:
	screen.visible = value
	if value:
		_focus_close.call_deferred()


func reset_scroll() -> void:
	%Scroll.scroll_vertical = 0


func _focus_close() -> void:
	if is_inside_tree() and screen.is_visible_in_tree():
		%Close.grab_focus()
