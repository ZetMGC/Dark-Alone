extends Control
## Текст и пометки используют одну раскладку TextParagraph, без пиксельных координат в save.

signal annotation_requested(kind: StringName, start: int, end: int)
signal erase_requested(index: int)
signal selection_changed(word: String)

var text: String = ""
var source_start: int = 0
var entry_id: StringName
var tool: StringName = &"select"
var marks: Array = []
var editing_enabled: bool = false:
	set(value):
		editing_enabled = value
		if not value:
			_dragging = false
var selection := Vector2i(-1, -1)
var _paragraph := TextParagraph.new()
var _dragging: bool = false
var _origin := Vector2i(-1, -1)
var _font: Font
var _font_size: int = 26
const MARGIN := Vector2(6, 5)


func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_IBEAM
	resized.connect(_shape)


func set_content(value: String, start: int, id: StringName) -> void:
	if text != value or source_start != start or entry_id != id:
		selection = Vector2i(-1, -1)
		_dragging = false
		selection_changed.emit("")
	text = value
	source_start = start
	entry_id = id
	_shape()


func set_marks(value: Array) -> void:
	marks = value.duplicate(true)
	queue_redraw()


func set_tool(value: StringName) -> void:
	tool = value
	_dragging = false
	mouse_default_cursor_shape = Control.CURSOR_CROSS if tool == &"erase" else Control.CURSOR_IBEAM
	if tool in [&"underline", &"circle"] and selection.x >= 0 and editing_enabled:
		annotation_requested.emit(tool, source_start + selection.x, source_start + selection.y)


func _shape() -> void:
	_dragging = false
	_font = get_theme_font("normal_font")
	_font_size = get_theme_font_size("normal_font_size")
	_paragraph.clear()
	_paragraph.width = maxf(40, size.x - MARGIN.x * 2)
	_paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	_paragraph.line_spacing = 4
	_paragraph.add_string(text, _font, _font_size)
	queue_redraw()


func range_rects(start: int, end: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var begin := maxi(0, start - source_start)
	var finish := mini(text.length(), end - source_start)
	if finish <= begin:
		return result
	var y := MARGIN.y
	var server := TextServerManager.get_primary_interface()
	for line in _paragraph.get_line_count():
		var range := _paragraph.get_line_range(line)
		var height := _paragraph.get_line_size(line).y
		if range.y > begin and range.x < finish:
			var segments := server.shaped_text_get_selection(_paragraph.get_line_rid(line), maxi(begin, range.x), mini(finish, range.y))
			for segment: Vector2 in segments:
				if absf(segment.y - segment.x) > 0.1:
					result.append(Rect2(Vector2(MARGIN.x + minf(segment.x, segment.y), y), Vector2(absf(segment.y - segment.x), height)))
		y += height + 4
	return result


func _letter(value: String) -> bool:
	return not value.is_empty() and (value.to_upper() != value.to_lower() or value in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", "_", "’"])


func word_at(point: Vector2) -> Vector2i:
	if text.is_empty() or not Rect2(Vector2.ZERO, size).has_point(point) or point.y > _paragraph.get_size().y + MARGIN.y:
		return Vector2i(-1, -1)
	var offset := clampi(_paragraph.hit_test(point - MARGIN), 0, text.length() - 1)
	if not _letter(text[offset]) and offset > 0:
		offset -= 1
	if not _letter(text[offset]):
		return Vector2i(-1, -1)
	var start := offset
	var end := offset + 1
	while start > 0 and _letter(text[start - 1]):
		start -= 1
	while end < text.length() and _letter(text[end]):
		end += 1
	for rect in range_rects(source_start + start, source_start + end):
		if rect.grow(3).has_point(point):
			return Vector2i(start, end)
	return Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if not editing_enabled or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			if tool == &"erase":
				for index in range(marks.size() - 1, -1, -1):
					for rect in range_rects(marks[index].start, marks[index].end):
						if rect.grow(5).has_point(event.position):
							erase_requested.emit(index)
							accept_event()
							return
			else:
				_origin = word_at(event.position)
				selection = _origin
				_dragging = _origin.x >= 0
				_update_selection()
		else:
			if _dragging and Rect2(Vector2.ZERO, size).has_point(event.position) and tool in [&"underline", &"circle"]:
				annotation_requested.emit(tool, source_start + selection.x, source_start + selection.y)
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var current := word_at(event.position)
		if current.x >= 0:
			selection = Vector2i(mini(current.x, _origin.x), maxi(current.y, _origin.y))
			_update_selection()
		accept_event()


func _update_selection() -> void:
	selection_changed.emit(text.substr(selection.x, selection.y - selection.x) if selection.x >= 0 else "")
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	if selection.x >= 0:
		for rect in range_rects(source_start + selection.x, source_start + selection.y):
			draw_rect(rect, Color(0.55, 0.39, 0.13, 0.16))
	_paragraph.draw(get_canvas_item(), MARGIN, Color("302b24"))
	for mark: Dictionary in marks:
		for rect in range_rects(mark.start, mark.end):
			var points := PackedVector2Array()
			if mark.kind == "underline":
				for step in 20:
					var amount := float(step) / 19
					points.append(Vector2(rect.position.x + amount * rect.size.x, rect.end.y - 2 + sin(amount * 7 + mark.start) * 0.65))
			else:
				var center := rect.get_center()
				var radius := rect.size * Vector2(0.5, 0.44) + Vector2(3, 0)
				for step in 65:
					var angle := TAU * step / 64.0
					points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) + Vector2(sin(angle * 3 + mark.start), cos(angle * 4) * 0.5))
			draw_polyline(points, Color(0.23, 0.19, 0.15, 0.87), 1.6, true)
