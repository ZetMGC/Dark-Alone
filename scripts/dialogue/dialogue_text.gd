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
