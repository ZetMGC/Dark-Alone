extends Control
## Кожа/бумага/сгиб средствами Godot. Ни изображений извне, ни состояния записей.

@export var leaf_only: bool = false
var open_amount: float = 1.0:
	set(value):
		open_amount = value
		queue_redraw()
var turn_amount: float = 0.0:
	set(value):
		turn_amount = value
		queue_redraw()
var turn_direction: float = 1.0
var bookmarked: bool = false:
	set(value):
		bookmarked = value
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if leaf_only:
		if turn_amount <= 0.001 or turn_amount >= 0.999:
			return
		var sweep := cos(turn_amount * PI) * turn_direction
		var edge := w * 0.5 + sweep * w * 0.46
		var fold := sin(turn_amount * PI) * 28.0
		var points := PackedVector2Array([Vector2(w * 0.5, 22), Vector2(edge, 18 - fold), Vector2(edge, h - 20 + fold), Vector2(w * 0.5, h - 22)])
		draw_colored_polygon(points, Color(0.79, 0.74, 0.59) if sweep > 0 else Color(0.68, 0.62, 0.48))
		draw_line(Vector2(edge, 20 - fold), Vector2(edge, h - 20 + fold), Color(0.3, 0.25, 0.18, 0.6), 2.0)
		return
	var width := lerpf(w * 0.46, w, open_amount)
	var left := (w - width) * 0.5
	# Отбрасываемая тень, кожаный футляр и видимые кромки листов.
	_rect(Rect2(left + 9, 10, width, h), Color(0, 0, 0, 0.48), 10)
	_rect(Rect2(left, 0, width, h - 5), Color("352a23"), 10)
	_rect(Rect2(left + 5, 5, width - 10, h - 15), Color("4a3b2d"), 8)
	for y in range(14, int(h) - 15, 8):
		draw_line(Vector2(left + 11, y), Vector2(left + 11, y + 3), Color("877252"), 1.0)
		draw_line(Vector2(left + width - 11, y), Vector2(left + width - 11, y + 3), Color("877252"), 1.0)
	if open_amount < 0.12:
		var font := ThemeDB.fallback_font
		var title := "ДНЕВНИК"
		var text_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 27)
		draw_string(font, Vector2(w * 0.5 - text_size.x * 0.5, h * 0.46), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("bca575"))
		draw_rect(Rect2(left + 35, 38, width - 70, h - 90), Color("8a7350"), false, 1)
		return
	for index in range(5, 0, -1):
		_rect(Rect2(left + 15, 17 + index * 2, width - 30, h - 43), Color(0.52 + index * 0.025, 0.48 + index * 0.025, 0.37 + index * 0.025), 3)
	var page := Rect2(left + 18, 16, width - 36, h - 42)
	_rect(page, Color("cabe9b"), 4)
	# Умеренная фактура: статичная и не попадает поверх чёткого текста.
	for index in 700:
		var x := fposmod(index * 73.17, page.size.x)
		var y := fposmod(index * 37.43, page.size.y)
		draw_rect(Rect2(page.position + Vector2(x, y), Vector2(2, 1)), Color(0.24, 0.18, 0.1, 0.08))
	for index in 12:
		var alpha := 0.025 + (12 - index) * 0.004
		draw_rect(page.grow(-index), Color(0.27, 0.19, 0.1, alpha), false, 1)
	var center := w * 0.5
	for index in range(-18, 19):
		var alpha := (1.0 - absf(float(index)) / 19.0) * 0.2
		draw_line(Vector2(center + index, 18), Vector2(center + index, h - 28), Color(0.16, 0.12, 0.08, alpha), 1)
	draw_line(Vector2(center, 18), Vector2(center, h - 28), Color("7d6b4c"), 2)
	if bookmarked:
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.87, 4), Vector2(w * 0.87 + 19, 4), Vector2(w * 0.87 + 19, 72), Vector2(w * 0.87 + 9, 62), Vector2(w * 0.87, 72)]), Color("7b392c"))


func _rect(rect: Rect2, color: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)
