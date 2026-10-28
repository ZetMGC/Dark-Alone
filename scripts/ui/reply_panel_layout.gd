extends RefCounted
## Общие размеры области ответов и действий: без пустой резервной строки.
static func rect(choices: VBoxContainer, area: Vector2) -> Rect2:
	var width: float = 280
	var height: float = 14
	for index in choices.get_child_count():
		var row = choices.get_child(index)
		width = maxf(width, row.natural_width() + 32)
		height += maxf(row.get_combined_minimum_size().y, row.body.get_line_height())
		if index > 0:
			height += choices.get_theme_constant("separation")
	width = minf(width, minf(680, area.x - 48))
	height = minf(height, minf(220, area.y * 0.32))
	return Rect2(Vector2((area.x - width) * 0.5, area.y - 60 - height), Vector2(width, height))
