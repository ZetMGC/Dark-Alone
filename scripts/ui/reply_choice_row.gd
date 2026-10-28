extends HBoxContainer
## Клавиша и реплика имеют отдельные колонки и общую базовую линию.
var key_label := Label.new()
var body := Label.new()
var text: String:
	get: return key_label.text + " " + body.text

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	key_label.custom_minimum_size.x = 34
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key_label)
	add_child(body)

func set_choice(caption: String, index: int, count: int, chosen: bool, font: Font = null, font_size: int = 18) -> void:
	body.text = caption if count == 1 else "%d. %s" % [index + 1, caption]
	for label in [key_label, body]:
		label.add_theme_font_size_override("font_size", font_size)
		if font != null:
			label.add_theme_font_override("font", font)
	set_selected(chosen)

func set_selected(chosen: bool) -> void:
	key_label.text = "[E]" if chosen else ""
	modulate = Color(0.88, 0.87, 0.79) if chosen else Color(0.63, 0.66, 0.64)

func natural_width() -> float:
	return body.get_theme_font("font").get_string_size(body.text, HORIZONTAL_ALIGNMENT_LEFT, -1, body.get_theme_font_size("font_size")).x + 42
