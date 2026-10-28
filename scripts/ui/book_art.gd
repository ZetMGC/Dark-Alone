extends Control
## Кожа/бумага/сгиб средствами Godot. Ни изображений извне, ни состояния записей.

@export var leaf_only: bool = false
var show_sketch: bool = false:
	set(value):
		show_sketch = value
		queue_redraw()
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
	_rect(Rect2(left, 0, width, h - 5), Color("252a26"), 10)
	_rect(Rect2(left + 5, 5, width - 10, h - 15), Color("3b4035"), 8)
	for line in range(8, int(h) - 8, 4):
		draw_line(Vector2(left + 6, line), Vector2(left + width - 6, line), Color(0.6, 0.56, 0.37, 0.065), 1)
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
	_rect(page, Color("ddcfac"), 4)
	# Тёплые края и светлая середина каждого листа создают объём без искажения текста.
	for band in 24:
		var amount := float(band) / 24
		var shade := Color(0.32, 0.23, 0.1, 0.002 + 0.04 * pow(absf(amount * 2 - 1), 2))
		draw_rect(Rect2(page.position + Vector2(amount * page.size.x, 0), Vector2(page.size.x / 24 + 1, page.size.y)), shade)
	# Умеренная фактура: статичная и не попадает поверх чёткого текста.
	for index in 2200:
		var x := fposmod(index * 73.17, page.size.x)
		var y := fposmod(index * 37.43, page.size.y)
		draw_rect(Rect2(page.position + Vector2(x, y), Vector2(1.2, 0.7)), Color(0.24, 0.18, 0.1, 0.07))
	for index in 32:
		var point := page.position + Vector2(fposmod(index * 161.17 + 31, page.size.x), fposmod(index * 113.43 + 12, page.size.y))
		draw_circle(point, 1 + fposmod(index * 7.7, 2.4), Color(0.45, 0.3, 0.13, 0.06))
	for index in 12:
		var alpha := 0.025 + (12 - index) * 0.004
		draw_rect(page.grow(-index), Color(0.27, 0.19, 0.1, alpha), false, 1)
	var center := w * 0.5
	for index in range(-18, 19):
		var alpha := (1.0 - absf(float(index)) / 19.0) * 0.2
		draw_line(Vector2(center + index, 18), Vector2(center + index, h - 28), Color(0.16, 0.12, 0.08, alpha), 1)
	draw_line(Vector2(center, 18), Vector2(center, h - 28), Color("7d6b4c"), 2)
	for y in range(38, int(h) - 36, 46):
		draw_line(Vector2(center - 3, y), Vector2(center + 3, y + 4), Color("a38e6b"), 1)
	# Лента у корешка и подогнутый нижний угол; табы остаются вне области текста.
	draw_colored_polygon(PackedVector2Array([Vector2(center + 8, h - 110), Vector2(center + 18, h - 110), Vector2(center + 23, h + 4), Vector2(center + 16, h - 2), Vector2(center + 11, h + 8)]), Color("713e37"))
	draw_colored_polygon(PackedVector2Array([Vector2(w - 44, h - 26), Vector2(w - 18, h - 52), Vector2(w - 18, h - 26)]), Color("b9aa87"))
	draw_colored_polygon(PackedVector2Array([Vector2(18, h - 52), Vector2(44, h - 26), Vector2(18, h - 26)]), Color("b9aa87"))
	if show_sketch and open_amount > 0.8:
		_draw_sketch(Rect2(w * 0.105, h * 0.53, w * 0.22, h * 0.25))
	if bookmarked:
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.87, 4), Vector2(w * 0.87 + 19, 4), Vector2(w * 0.87 + 19, 72), Vector2(w * 0.87 + 9, 62), Vector2(w * 0.87, 72)]), Color("7b392c"))


func _draw_sketch(rect: Rect2) -> void:
	var color := Color(0.25, 0.22, 0.17, 0.19)
	for shift in [Vector2.ZERO, Vector2(1.3, -1), Vector2(-0.8, 1.4)]:
		draw_rect(Rect2(rect.position + shift, rect.size), color, false, 1)
		draw_rect(Rect2(rect.position + shift + Vector2(9, 9), rect.size - Vector2(18, 18)), color, false, 1)
		draw_line(rect.position + shift + Vector2(rect.size.x * 0.5, 9), rect.position + shift + Vector2(rect.size.x * 0.5, rect.size.y - 9), color)
		draw_line(Vector2(rect.position.x - 8, rect.end.y + 5) + shift, Vector2(rect.end.x + 12, rect.end.y + 5) + shift, color)
	for index in 24:
		var origin := rect.position + Vector2(fposmod(index * 31.7, rect.size.x - 20) + 10, fposmod(index * 19.3, rect.size.y - 22) + 10)
		draw_line(origin, origin + Vector2(9, -5), Color(0.2, 0.18, 0.14, 0.05), 1)


func _rect(rect: Rect2, color: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)
