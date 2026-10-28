class_name JournalPaperPages
extends Control
## Разворот личных записей: текст/связи принадлежат JournalNotebook.

signal hint_changed(text: String)
signal navigation_changed
var notebook: JournalNotebook
var section: StringName = &"notes"
var sheet: int = 0
var recipe_index: int = 0
var recipe_page: int = 0
var editing_enabled: bool = false:
	set(value):
		if not value:
			finish_edit()
			_drag_id = -1
			_link_id = -1
		editing_enabled = value
var _font: Font = preload("res://assets/fonts/caveat/Caveat.ttf")
var _ink := Color("353f42")
var _editor: TextEdit
var _editing_id: int = -1
var _new_position := Vector2.ZERO
var _selected: int = -1
var _drag_id: int = -1
var _link_id: int = -1
var _drag_offset := Vector2.ZERO
var _pointer := Vector2.ZERO
var _recipe_pages: Array[Dictionary] = []


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	_editor = TextEdit.new()
	_editor.name = "Writer"
	_editor.visible = false
	_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_editor.add_theme_font_override("font", _font)
	_editor.add_theme_font_size_override("font_size", 26)
	_editor.add_theme_color_override("font_color", _ink)
	_editor.add_theme_color_override("caret_color", _ink)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("ddcfac")
	paper.set_content_margin_all(8)
	_editor.add_theme_stylebox_override("normal", paper)
	_editor.add_theme_stylebox_override("focus", paper)
	add_child(_editor)
	_editor.gui_input.connect(_editor_input)
	_editor.focus_exited.connect(_finish_after_focus_loss.call_deferred)
	resized.connect(func() -> void:
		finish_edit()
		queue_redraw()
	)


func bind(value: JournalNotebook) -> void:
	if notebook == value:
		return
	finish_edit()
	if notebook != null and notebook.changed.is_connected(queue_redraw):
		notebook.changed.disconnect(queue_redraw)
	notebook = value
	notebook.changed.connect(queue_redraw)
	recipe_index = 0
	recipe_page = 0
	queue_redraw()


func set_section(value: StringName) -> void:
	finish_edit()
	section = value
	_drag_id = -1
	_link_id = -1
	queue_redraw()


func request_page(direction: int) -> bool:
	finish_edit()
	if section == &"notes":
		if sheet + direction < 0 or sheet + direction >= JournalNotebook.SHEETS:
			return false
		sheet += direction
	else:
		if recipe_page + direction >= 0 and recipe_page + direction < _recipe_pages.size():
			recipe_page += direction
		else:
			var target := recipe_index + direction
			if target < 0 or target >= notebook.get_recipes().size():
				return false
			recipe_index = target
			recipe_page = 0
	queue_redraw()
	return true


func can_request_page(direction: int) -> bool:
	if notebook == null:
		return false
	if section == &"notes":
		return sheet + direction >= 0 and sheet + direction < JournalNotebook.SHEETS
	var recipes := notebook.get_recipes()
	if not recipes.is_empty():
		recipe_index = clampi(recipe_index, 0, recipes.size() - 1)
		_recipe_pages = BookPaginator.paginate(recipes[recipe_index].text, _font, 28, _recipe_rect().size)
	else:
		_recipe_pages.clear()
	return (recipe_page + direction >= 0 and recipe_page + direction < _recipe_pages.size()) or (recipe_index + direction >= 0 and recipe_index + direction < notebook.get_recipes().size())


func _recipe_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.55, 70), Vector2(size.x * 0.41, size.y - 125))


func note_rect(note: Dictionary) -> Rect2:
	var height := clampf(110 + str(note.get("text", "")).length() * 0.3, 150, 210)
	var extent := Vector2(minf(260, size.x * 0.25), minf(height, size.y * 0.46))
	var center := Vector2(note.x * size.x, note.y * size.y).clamp(extent * 0.5 + Vector2(4, 56), size - extent * 0.5 - Vector2(4, 36))
	return Rect2(center - extent * 0.5, extent)


func _safe_position(point: Vector2) -> Vector2:
	var extent := Vector2(minf(260, size.x * 0.25), minf(150, size.y * 0.34)) * 0.5
	var result := point.clamp(extent + Vector2(4, 58), size - extent - Vector2(4, 36))
	var gutter := size.x * 0.5
	if absf(result.x - gutter) < extent.x + 24:
		result.x = gutter + (extent.x + 24) * (-1 if result.x < gutter else 1)
	return result / size


func _note_at(point: Vector2) -> int:
	var notes := notebook.get_notes(sheet)
	notes.reverse()
	for note in notes:
		if note_rect(note).has_point(point):
			return note.id
	return -1


func _note(id: int) -> Dictionary:
	for note in notebook.get_notes(sheet):
		if note.id == id:
			return note
	return {}


func begin_edit(id: int = -1, point: Vector2 = Vector2.ZERO) -> void:
	if not editing_enabled or notebook == null:
		return
	if not finish_edit():
		return
	_editing_id = id
	if section == &"notes":
		_new_position = _safe_position(point)
		var note := _note(id)
		var rect := note_rect({"x": _new_position.x, "y": _new_position.y}) if note.is_empty() else note_rect(note)
		_editor.position = rect.position
		_editor.size = rect.size
		_editor.text = "" if note.is_empty() else str(note.text)
		_editor.placeholder_text = "Мысль, вопрос, наблюдение…"
	else:
		var rect := _recipe_rect()
		_editor.position = rect.position
		_editor.size = rect.size
		var recipes := notebook.get_recipes()
		_editor.text = "" if id < 0 else str(recipes[recipe_index].text)
		_editor.placeholder_text = "Название\n\nСостав и пропорции\n\nКак готовил\n\nЧто изменить в следующий раз"
	_editor.show()
	_editor.grab_focus()
	hint_changed.emit("Ctrl+Enter — оставить запись · Esc — отменить правку")


func finish_edit(cancel: bool = false) -> bool:
	if _editor == null or not _editor.visible:
		return true
	var text := _editor.text
	_editor.hide()
	if cancel or text.strip_edges().is_empty():
		hint_changed.emit(default_hint())
		return true
	var accepted := false
	if section == &"notes":
		accepted = notebook.add_note(text, _new_position, sheet) > 0 if _editing_id < 0 else notebook.update_note(_editing_id, text)
	else:
		if _editing_id < 0:
			accepted = notebook.add_recipe(text) > 0
			if accepted:
				recipe_index = notebook.get_recipes().size() - 1
		else:
			accepted = notebook.update_recipe(_editing_id, text)
		recipe_page = 0
	if not accepted:
		# Не терять введённое при ограничении длины/числа записей.
		_editor.show()
		_editor.grab_focus()
		hint_changed.emit("Не удалось оставить запись: заметка до 320 знаков, рецепт до 4000; на развороте до 8 заметок")
	else:
		hint_changed.emit(default_hint())
	queue_redraw()
	return accepted


func _finish_after_focus_loss() -> void:
	if not _editor.has_focus():
		finish_edit()


func default_hint() -> String:
	return "Двойной щелчок — писать · тянуть — переместить · Shift + тянуть — стрелка · ПКМ — обвести · Del — стереть" if section == &"notes" else "Двойной щелчок по странице — писать · PgUp / PgDn — листать · Del — стереть выбранный рецепт"


func _editor_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			finish_edit(true)
			accept_event()
		elif event.keycode == KEY_ENTER and event.ctrl_pressed:
			finish_edit()
			accept_event()


func _gui_input(event: InputEvent) -> void:
	if not editing_enabled or notebook == null:
		return
	if event is InputEventMouseMotion:
		_pointer = event.position
		if _drag_id > 0:
			notebook.move_note(_drag_id, _safe_position(event.position - _drag_offset))
		queue_redraw()
	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		if section == &"notes":
			notebook.remove_note(_selected)
		elif not notebook.get_recipes().is_empty():
			notebook.remove_recipe(notebook.get_recipes()[recipe_index].id)
			recipe_index = maxi(0, recipe_index - 1)
			recipe_page = 0
		accept_event()
		queue_redraw()
		navigation_changed.emit()
	if not event is InputEventMouseButton:
		return
	if event.pressed:
		grab_focus()
	if section == &"recipes":
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if event.position.x < size.x * 0.44:
				var start := floori(float(recipe_index) / 8) * 8
				var row := floori((event.position.y - 90) / 37)
				var index := start + row
				if row >= 0 and row <= mini(8, notebook.get_recipes().size() - start):
					recipe_index = mini(index, maxi(0, notebook.get_recipes().size() - 1))
					recipe_page = 0
					if row == mini(8, notebook.get_recipes().size() - start):
						begin_edit()
			elif event.double_click:
				var recipes := notebook.get_recipes()
				begin_edit(-1 if recipes.is_empty() else int(recipes[recipe_index].id))
			queue_redraw()
			navigation_changed.emit()
		return
	var id := _note_at(event.position)
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_selected = id
			if event.double_click:
				begin_edit(id, event.position)
			elif event.shift_pressed:
				_link_id = id
			else:
				_drag_id = id
				if id > 0:
					_drag_offset = event.position - note_rect(_note(id)).get_center()
		else:
			if _link_id > 0:
				if not notebook.link_notes(_link_id, id):
					notebook.unlink_notes(_link_id, id)
			_link_id = -1
			_drag_id = -1
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		notebook.toggle_circle(id)
	queue_redraw()


func _write(text: String, rect: Rect2, font_size: int = 27, color: Color = _ink) -> void:
	var paragraph := TextParagraph.new()
	paragraph.width = rect.size.x
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text, _font, font_size)
	while paragraph.get_size().y > rect.size.y and font_size > 17:
		font_size -= 1
		paragraph.clear()
		paragraph.width = rect.size.x
		paragraph.add_string(text, _font, font_size)
	paragraph.draw(get_canvas_item(), rect.position, color)


func _arrow(start: Vector2, end: Vector2) -> void:
	var direction := (end - start).normalized()
	draw_polyline(PackedVector2Array([start, start.lerp(end, 0.5) + direction.orthogonal() * 8, end]), _ink, 1.3, true)
	draw_line(end, end - direction.rotated(0.4) * 12, _ink, 1.3, true)
	draw_line(end, end - direction.rotated(-0.4) * 12, _ink, 1.3, true)


func _draw() -> void:
	if notebook == null:
		return
	if section == &"recipes":
		_draw_recipes()
		return
	_write("На полях", Rect2(20, 0, size.x * 0.4, 45), 38)
	_write("Мысли, вопросы, связи…", Rect2(size.x * 0.56, 8, size.x * 0.4, 45), 27)
	var notes := notebook.get_notes(sheet)
	for link in notebook.get_links():
		var a := _note(link.from)
		var b := _note(link.to)
		if a.is_empty() or b.is_empty():
			continue
		var start := note_rect(a).get_center()
		var end := note_rect(b).get_center()
		var direction := (end - start).normalized()
		var radii := note_rect(a).size * 0.5
		var distance := 1.0 / sqrt(pow(direction.x / radii.x, 2) + pow(direction.y / radii.y, 2)) if direction.length_squared() > 0 else 0.0
		_arrow(start + direction * (distance + 5), end - direction * (distance + 5))
	if _link_id > 0:
		_arrow(note_rect(_note(_link_id)).get_center(), _pointer)
	for note in notes:
		var rect := note_rect(note)
		if note.circled:
			var points := PackedVector2Array()
			for index in 65:
				var angle := TAU * index / 64.0
				points.append(rect.get_center() + Vector2(cos(angle) * (rect.size.x * 0.5 + sin(angle * 5) * 1.5), sin(angle) * rect.size.y * 0.5))
			draw_polyline(points, _ink, 1.3, true)
		_write(note.text, rect.grow(-19), 24)
		if note.id == _selected:
			draw_line(rect.position + Vector2(20, rect.size.y - 10), rect.end - Vector2(20, 10), Color(_ink, 0.25), 1)
	if notes.is_empty():
		_write("Здесь можно оставить свою мысль.\n\nДважды коснуться бумаги —\nи начать писать.", Rect2(size.x * 0.08, size.y * 0.28, size.x * 0.32, 180), 28, Color(_ink, 0.45))
		_write("Обвести важное.\nСоединить то, что кажется связанным.\n\nНе забыть проверить.", Rect2(size.x * 0.58, size.y * 0.34, size.x * 0.35, 180), 27, Color(_ink, 0.45))
	_write(str(sheet * 2 + 1), Rect2(20, size.y - 32, 80, 30), 22)
	_write(str(sheet * 2 + 2), Rect2(size.x - 50, size.y - 32, 50, 30), 22)


func _draw_recipes() -> void:
	_write("Из моей барной тетради", Rect2(20, 0, size.x * 0.44, 80), 36)
	var recipes := notebook.get_recipes()
	var start := floori(float(recipe_index) / 8) * 8
	var count := mini(8, recipes.size() - start)
	for row in count:
		_write(str(recipes[start + row].text).get_slice("\n", 0).left(34), Rect2(28, 90 + row * 37, size.x * 0.38, 36), 27)
	_write("Ещё один рецепт…", Rect2(28, 90 + count * 37, size.x * 0.38, 36), 25, Color(_ink, 0.55))
	var rect := _recipe_rect()
	_write("Рецепт / проба", Rect2(rect.position.x, 0, rect.size.x, 60), 38)
	if recipes.is_empty():
		_write("Название\n\nСостав и пропорции\n\nКак готовил\n\nЧто изменить в следующий раз", rect, 29, Color(_ink, 0.4))
		return
	recipe_index = clampi(recipe_index, 0, recipes.size() - 1)
	_recipe_pages = BookPaginator.paginate(recipes[recipe_index].text, _font, 28, rect.size)
	recipe_page = clampi(recipe_page, 0, _recipe_pages.size() - 1)
	_write(_recipe_pages[recipe_page].text, rect, 28)
	_write(str(recipe_page + 1), Rect2(size.x - 50, size.y - 32, 50, 30), 22)
