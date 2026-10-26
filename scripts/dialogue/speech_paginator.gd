class_name SpeechPaginator
extends RefCounted
## Границы в исходном plain-тексте, нормальный и жирный шрифты измеряются вместе.

static func paginate(text: String, regular: Font, bold: Font, font_size: int, area: Vector2) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var paragraph := TextParagraph.new()
	paragraph.width = maxf(area.x, 40)
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var parts := text.split("**")
	var literal := parts.size() % 2 == 0
	if parts.size() % 2 == 0:
		paragraph.add_string(text, regular, font_size)
	else:
		for index in parts.size():
			if not parts[index].is_empty():
				paragraph.add_string(parts[index], bold if index % 2 == 1 else regular, font_size)
	var start := 0
	var height := 0.0
	for line in paragraph.get_line_count():
		var line_height := paragraph.get_line_size(line).y
		var line_start := paragraph.get_line_range(line).x
		if height > 0 and height + line_height > maxf(area.y - 8, line_height):
			pages.append({"start": start, "end": line_start, "text": DialogueText.styled_slice(text, start, line_start - start), "literal": literal})
			start = line_start
			height = 0
		height += line_height
	var end := DialogueText.plain(text).length()
	pages.append({"start": start, "end": end, "text": DialogueText.styled_slice(text, start, end - start), "literal": literal})
	return pages
