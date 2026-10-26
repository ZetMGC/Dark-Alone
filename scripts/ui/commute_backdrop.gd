extends Control
## Абстрактная TEST-декорация маршрута, не карта канонического города/дома.

var progress: float = 0.0
var at_home: bool = false
var to_home: bool = true


func _draw() -> void:
	var factor := size / Vector2(640, 360)
	draw_set_transform(Vector2.ZERO, 0.0, factor)
	draw_rect(Rect2(0, 0, 640, 360), Color("11191e"))
	if at_home:
		draw_rect(Rect2(0, 0, 640, 360), Color("252827"))
		draw_rect(Rect2(120, 55, 176, 175), Color("111516"))
		draw_rect(Rect2(130, 65, 156, 155), Color("35464e"))
		for y in [115, 170]:
			draw_rect(Rect2(130, y, 156, 6), Color("181f20"))
		draw_rect(Rect2(204, 65, 6, 155), Color("181f20"))
		draw_rect(Rect2(95, 230, 228, 10), Color("111718"))
		draw_rect(Rect2(400, 260, 200, 16), Color("151918"))
		draw_rect(Rect2(420, 276, 10, 84), Color("111413"))
		draw_rect(Rect2(520, 230, 45, 30), Color("353b34"))
	else:
		var direction := 1.0 if to_home else -1.0
		for depth: int in [0, 1]:
			var offset := progress * direction * (85.0 + depth * 150.0)
			for index in range(-3, 12):
				var x := fposmod(index * 90.0 - offset + 270.0, 900.0) - 180.0
				var top := 72.0 + posmod(index * 37 + depth * 13, 95)
				var color := Color("19272e") if depth == 0 else Color("0b1216")
				draw_rect(Rect2(x, top, 76, 270 - top), color)
				for row in 3:
					for column in 3:
						if posmod(index + row * 3 + column * 5, 4) == 0:
							draw_rect(Rect2(x + 12 + column * 20, top + 18 + row * 28, 6, 9), Color("615b43"))
		draw_rect(Rect2(0, 268, 640, 92), Color("0a1013"))
		for index in 8:
			var x := fposmod(index * 110.0 - progress * direction * 450.0, 800.0) - 90.0
			draw_rect(Rect2(x, 294, 54, 3), Color("39403b"))
	# Статичная сетка, без стробирования и временного шума.
	for y in range(0, 360, 4):
		draw_line(Vector2(0, y), Vector2(640, y), Color(0, 0, 0, 0.08), 1.0)
