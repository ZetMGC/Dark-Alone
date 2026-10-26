class_name BookPaginator
extends RefCounted
## Страницы — только представление; позиции хранятся в символах исходного текста.


static func paginate(text: String, font: Font, font_size: int, area: Vector2) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	if text.is_empty() or font == null:
		pages.append({"start": 0, "end": text.length(), "text": text})
		return pages
	var paragraph := TextParagraph.new()
	paragraph.width = maxf(area.x, 40.0)
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.line_spacing = 4.0
	paragraph.add_string(text, font, font_size)
	var start: int = 0
	var height: float = 0.0
	for line in paragraph.get_line_count():
		var line_height := paragraph.get_line_size(line).y + 4.0
		var line_start := paragraph.get_line_range(line).x
		if height > 0.0 and height + line_height > maxf(area.y - 8.0, line_height):
			pages.append({"start": start, "end": line_start, "text": text.substr(start, line_start - start)})
			start = line_start
			height = 0.0
		height += line_height
	pages.append({"start": start, "end": text.length(), "text": text.substr(start)})
	return pages


static func page_for_offset(pages: Array[Dictionary], offset: int) -> int:
	for index in pages.size():
		if offset < int(pages[index].end) or index == pages.size() - 1:
			return index
	return 0
