class_name DialogueText
extends RefCounted
## Только парные **важные слова**; остальной текст всегда буквальный.

static func plain(text: String) -> String:
	var parts := text.split("**")
	return "".join(parts) if parts.size() % 2 == 1 else text


static func write(label: RichTextLabel, text: String) -> void:
	label.clear()
	var parts := text.split("**")
	if parts.size() % 2 == 0:
		label.add_text(text)
		return
	for index in parts.size():
		if index % 2 == 1:
			label.push_bold()
		label.add_text(parts[index])
		if index % 2 == 1:
			label.pop()


static func styled_slice(text: String, start: int, length: int) -> String:
	var parts := text.split("**")
	if parts.size() % 2 == 0:
		return text.substr(start, length)
	var result := ""
	var offset := 0
	for index in parts.size():
		var finish := offset + parts[index].length()
		var from := maxi(start, offset)
		var to := mini(start + length, finish)
		if to > from:
			var chunk := parts[index].substr(from - offset, to - from)
			result += "**" + chunk + "**" if index % 2 == 1 else chunk
		offset = finish
	return result
