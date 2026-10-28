class_name JournalPaperPages
extends Control
## Только найденные слова, авторские рецепты и выбор вывода. Свободного письма нет.

signal hint_changed(text: String)
signal navigation_changed
var journal: Journal
var section: StringName = &"notes"
var sheet: int = 0
var recipe_index: int = 0
var recipe_page: int = 0
var editing_enabled: bool = false:
	set(value):
		editing_enabled = value
		queue_redraw()
var _font: Font = preload("res://assets/fonts/caveat/Caveat.ttf")
var _ink := Color("353f42")
var _pending_group: StringName = &""
var _pending_evidence := PackedStringArray()
var _recipe_pages: Array[Dictionary] = []


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	resized.connect(queue_redraw)


func bind(value: Journal) -> void:
	if journal == value:
		return
	if journal != null and journal.reasoning.changed.is_connected(_on_reasoning_changed):
		journal.reasoning.changed.disconnect(_on_reasoning_changed)
	journal = value
	journal.reasoning.changed.connect(_on_reasoning_changed)
	_pending_group = &""
	queue_redraw()


func _on_reasoning_changed() -> void:
	_pending_group = &""
	_pending_evidence.clear()
	queue_redraw()


func set_section(value: StringName) -> void:
	section = value
	_pending_group = &""
	_pending_evidence.clear()
	queue_redraw()


func finish_edit(_cancel: bool = false) -> bool:
	# Совместимость Panel: редактора текста больше нет.
	return true


func default_hint() -> String:
	return "Точка у готовой группы — сделать вывод · Esc — отменить выбор" if section == &"notes" else "Угол страницы / PgUp / PgDn — листать · рецепты появляются по мере знакомства с баром"


func can_request_page(direction: int) -> bool:
	if journal == null:
		return false
	if section == &"notes":
		return sheet + direction >= 0 and sheet + direction < 8
	_paginate_recipe()
	return (recipe_page + direction >= 0 and recipe_page + direction < _recipe_pages.size()) or (recipe_index + direction >= 0 and recipe_index + direction < journal.get_journal_recipes().size())


func request_page(direction: int) -> bool:
	if not can_request_page(direction):
		return false
	_pending_group = &""
	if section == &"notes":
		sheet += direction
	elif recipe_page + direction >= 0 and recipe_page + direction < _recipe_pages.size():
		recipe_page += direction
	else:
		recipe_index += direction
		recipe_page = 0
	queue_redraw()
	navigation_changed.emit()
	return true


func group_rect(group: Dictionary) -> Rect2:
	var width := minf(380, size.x * 0.37)
	var height := 92 + ceilf(group.terms.size() / 2.0) * 38
	if not group.conclusion.is_empty():
		height += 100
	var extent := Vector2(width, height)
	var center := Vector2(group.position[0], group.position[1]) * size
	center = center.clamp(extent * 0.5 + Vector2(8, 52), size - extent * 0.5 - Vector2(8, 38))
	return Rect2(center - extent * 0.5, extent)


func conclusion_rect(group: Dictionary) -> Rect2:
	var rect := group_rect(group)
	return Rect2(rect.position + Vector2(32, 74 + ceilf(group.terms.size() / 2.0) * 38), Vector2(rect.size.x - 64, 82))


func get_word_rects(group: Dictionary) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var rect := group_rect(group)
	var column_width := (rect.size.x - 72) * 0.5
	for index in group.terms.size():
		var title: String = journal.get_definition(StringName(group.terms[index])).title
		var width := minf(column_width, _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 2)
		result.append(Rect2(rect.position + Vector2(32 + (index % 2) * (column_width + 8), 62 + floori(index / 2.0) * 38), Vector2(width, 35)))
	return result


func _options_rect() -> Rect2:
	return Rect2(size.x * 0.55, 65, size.x * 0.41, size.y - 115)


func get_option_rect(index: int) -> Rect2:
	var rect := _options_rect()
	return Rect2(rect.position + Vector2(12, 76 + index * 78), Vector2(rect.size.x - 24, 72))


func get_pending_group() -> StringName:
	return _pending_group


func choose_option(index: int) -> bool:
	if section != &"notes" or not editing_enabled or journal == null or not is_visible_in_tree():
		return false
	for group in journal.get_reasoning_groups(sheet):
		if group.id == str(_pending_group) and group.ready and group.conclusion.is_empty() and index >= 0 and index < group.options.size():
			var accepted := journal.choose_conclusion(_pending_group, StringName(group.options[index].id), _pending_evidence)
			if accepted:
				hint_changed.emit("Вывод записан. Его можно использовать в разговоре; это ещё не доказательство.")
			return accepted
	return false


func get_conclusion_button_rect(group: Dictionary) -> Rect2:
	var rect := group_rect(group)
	var center := Vector2(minf(rect.end.x + 12, size.x - 18), rect.get_center().y)
	return Rect2(center - Vector2(18, 18), Vector2(36, 36))


func get_visible_links() -> Array:
	return journal.reasoning.get_links(sheet, journal.get_known_term_ids()) if journal != null else []


func open_conclusion(group_id: StringName) -> bool:
	if section != &"notes" or not editing_enabled or journal == null or not is_visible_in_tree():
		return false
	for group in journal.get_reasoning_groups(sheet):
		if group.id == str(group_id) and group.ready and group.conclusion.is_empty():
			_pending_group = group_id
			_pending_evidence = PackedStringArray(group.terms)
			hint_changed.emit("Какой вывод следует из этих слов? Выберите вариант на бумаге.")
			queue_redraw()
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if not editing_enabled or journal == null:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and _pending_group != &"":
			_pending_group = &""
			hint_changed.emit(default_hint())
			queue_redraw()
			accept_event()
		elif _pending_group != &"" and event.keycode >= KEY_1 and event.keycode <= KEY_4:
			choose_option(event.keycode - KEY_1)
			accept_event()
	if event is InputEventMouseMotion and section == &"notes":
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		for group in journal.get_reasoning_groups(sheet):
			if group.ready and group.conclusion.is_empty() and get_conclusion_button_rect(group).has_point(event.position):
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	grab_focus()
	if section == &"recipes":
		if event.position.x < size.x * 0.44:
			var index := floori((event.position.y - 90) / 37) + floori(recipe_index / 8.0) * 8
			if index >= 0 and index < journal.get_journal_recipes().size():
				recipe_index = index
				recipe_page = 0
				queue_redraw()
				navigation_changed.emit()
		return
	if _pending_group != &"":
		for index in 4:
			if get_option_rect(index).has_point(event.position):
				choose_option(index)
		return
	for group in journal.get_reasoning_groups(sheet):
		if get_conclusion_button_rect(group).has_point(event.position) and open_conclusion(StringName(group.id)):
			accept_event()
			return


func _write(text: String, rect: Rect2, font_size: int = 27, color: Color = _ink) -> void:
	var paragraph := TextParagraph.new()
	paragraph.width = rect.size.x
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.line_spacing = 4
	paragraph.add_string(text, _font, font_size)
	while paragraph.get_size().y > rect.size.y and font_size > 17:
		font_size -= 1
		paragraph.clear()
		paragraph.width = rect.size.x
		paragraph.add_string(text, _font, font_size)
	paragraph.draw(get_canvas_item(), rect.position, color)


func _oval(rect: Rect2) -> void:
	var points := PackedVector2Array()
	for index in 65:
		var angle := TAU * index / 64.0
		points.append(rect.get_center() + Vector2(signf(cos(angle)) * pow(absf(cos(angle)), 0.5) * rect.size.x * 0.5, signf(sin(angle)) * pow(absf(sin(angle)), 0.5) * rect.size.y * 0.5))
	draw_polyline(points, _ink, 1.4, true)


func _draw() -> void:
	if journal == null:
		return
	if section == &"recipes":
		_draw_recipes()
		return
	_write("Слова и связи", Rect2(20, 0, size.x * 0.4, 45), 38)
	_write("Что из этого следует?", Rect2(size.x * 0.56, 8, size.x * 0.4, 45), 29)
	var groups := journal.get_reasoning_groups(sheet)
	_draw_links(groups)
	for group in groups:
		var rect := group_rect(group)
		_write(group.title, Rect2(rect.position + Vector2(32, 22), Vector2(rect.size.x - 64, 34)), 26)
		var rects := get_word_rects(group)
		for index in rects.size():
			_write(journal.get_definition(StringName(group.terms[index])).title, rects[index], 24)
		if group.get("words_ready", group.ready):
			_oval(rect)
			if group.ready and group.conclusion.is_empty():
				var point := get_conclusion_button_rect(group).get_center()
				draw_circle(point, 8, Color(_ink, 0.13))
				draw_circle(point, 3.8, _ink)
		if not group.conclusion.is_empty():
			var text := ""
			for option in group.options:
				if option.id == group.conclusion.option_id:
					text = option.text
			var area := conclusion_rect(group)
			draw_line(area.position - Vector2(0, 6), area.position + Vector2(area.size.x, -6), Color(_ink, 0.3), 1)
			_write(text, area, 25)
	if groups.is_empty():
		_write("Новые слова из разговоров
будут появляться здесь.

Связанные сведения — рядом.", Rect2(size.x * 0.08, size.y * 0.3, size.x * 0.34, 180), 29, Color(_ink, 0.5))
	if _pending_group != &"":
		var rect := _options_rect()
		draw_rect(rect.grow(8), Color("ddcfac"))
		_write("Я думаю, что…", Rect2(rect.position, Vector2(rect.size.x, 65)), 35)
		for group in groups:
			if group.id == str(_pending_group):
				for index in group.options.size():
					_write(str(index + 1) + ". " + group.options[index].text, get_option_rect(index), 27)
	_write(str(sheet * 2 + 1), Rect2(20, size.y - 32, 80, 30), 22)
	_write(str(sheet * 2 + 2), Rect2(size.x - 50, size.y - 32, 50, 30), 22)


func _draw_links(groups: Array) -> void:
	for link in get_visible_links():
		var a := Rect2()
		var b := Rect2()
		for group in groups:
			if group.id == link.from:
				a = group_rect(group)
			if group.id == link.to:
				b = group_rect(group)
		if a.size == Vector2.ZERO or b.size == Vector2.ZERO:
			continue
		var direction := a.get_center().direction_to(b.get_center())
		if direction.is_zero_approx():
			continue
		var a_radius := pow(pow(absf(direction.x) / (a.size.x * 0.5), 4) + pow(absf(direction.y) / (a.size.y * 0.5), 4), -0.25)
		var b_radius := pow(pow(absf(direction.x) / (b.size.x * 0.5), 4) + pow(absf(direction.y) / (b.size.y * 0.5), 4), -0.25)
		var start := a.get_center() + direction * (a_radius + 4)
		var end := b.get_center() - direction * (b_radius + 4)
		var points := PackedVector2Array()
		for index in 13:
			var t := index / 12.0
			points.append(start.lerp(end, t) + direction.orthogonal() * sin(t * PI) * 10)
		draw_polyline(points, _ink, 1.3, true)
		var tangent := points[-2].direction_to(end)
		draw_line(end, end - tangent.rotated(0.4) * 11, _ink, 1.3, true)
		draw_line(end, end - tangent.rotated(-0.4) * 11, _ink, 1.3, true)


func get_page_preview(direction: int) -> Dictionary:
	if not can_request_page(direction):
		return {}
	var state := {"sheet": sheet, "recipe_index": recipe_index, "recipe_page": recipe_page}
	if section == &"notes":
		state.sheet += direction
	elif recipe_page + direction >= 0 and recipe_page + direction < _recipe_pages.size():
		state.recipe_page += direction
	else:
		state.recipe_index += direction
		state.recipe_page = 0
	return state


func _recipe_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.55, 70), Vector2(size.x * 0.41, size.y - 125))


func _paginate_recipe() -> void:
	var recipes := journal.get_journal_recipes()
	_recipe_pages.clear()
	if not recipes.is_empty():
		recipe_index = clampi(recipe_index, 0, recipes.size() - 1)
		_recipe_pages = BookPaginator.paginate(recipes[recipe_index].text, _font, 28, _recipe_rect().size)
		recipe_page = clampi(recipe_page, 0, _recipe_pages.size() - 1)


func _draw_recipes() -> void:
	_write("Барная тетрадь", Rect2(20, 0, size.x * 0.44, 80), 36)
	var recipes := journal.get_journal_recipes()
	var start := floori(recipe_index / 8.0) * 8
	for row in mini(8, recipes.size() - start):
		_write(recipes[start + row].title, Rect2(28, 90 + row * 37, size.x * 0.38, 36), 27)
	var rect := _recipe_rect()
	if recipes.is_empty():
		_write("Пока здесь нет рецептов.

Найденные способы приготовления
появятся на этих страницах.", rect, 29, Color(_ink, 0.5))
		return
	_paginate_recipe()
	_write(_recipe_pages[recipe_page].text, rect, 28)
	_write(str(recipe_page + 1), Rect2(size.x - 50, size.y - 32, 50, 30), 22)
