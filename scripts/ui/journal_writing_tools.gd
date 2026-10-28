extends Control
## Предметы письма вместо панели инструментов приложения.

signal tool_requested(index: int)
var selected: int = 0
var enabled: bool = true
var _font: Font = preload("res://assets/fonts/caveat/Caveat.ttf")


func _gui_input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected = clampi(int(event.position.x / (size.x / 4)), 0, 3)
		tool_requested.emit(selected)
		queue_redraw()
		accept_event()


func _draw() -> void:
	var labels := ["читать", "подчеркнуть", "обвести", "стереть"]
	for index in 4:
		var x := index * size.x / 4 + 8
		var width := size.x / 4 - 20
		var y := 35.0 if selected == index else 40.0
		var color := Color("8d7951") if index != 3 else Color("a89b8d")
		draw_line(Vector2(x + 5, y + 4), Vector2(x + width, y + 4), Color(0, 0, 0, 0.25), 9)
		draw_line(Vector2(x + 5, y), Vector2(x + width, y), color, 7)
		draw_line(Vector2(x + 8, y - 2), Vector2(x + width, y - 2), color.lightened(0.25), 1)
		if index != 3:
			draw_colored_polygon(PackedVector2Array([Vector2(x + 5, y - 4), Vector2(x - 5, y), Vector2(x + 5, y + 4)]), Color("bdac85"))
			draw_line(Vector2(x - 5, y), Vector2(x - 1, y), Color("303632"), 2)
		draw_string(_font, Vector2(x, 20), labels[index], HORIZONTAL_ALIGNMENT_LEFT, width + 10, 21, Color("b6aa8c"))
