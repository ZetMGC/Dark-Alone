extends PanelContainer
## Общие пассивные подсказки с затуханием и защитой от повторов.
var remaining: float = 0.0
var seen: Dictionary = {}
var label: Label
func _ready() -> void:
	label = Label.new()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -324
	offset_right = -24
	offset_top = 24
	custom_minimum_size.x = 300
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.055, 0.9)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	hide()
func show_hint(message: String, key: String = "", once: bool = true) -> void:
	var id := message if key.is_empty() else key
	if message.is_empty() or (once and seen.has(id)):
		return
	seen[id] = true
	label.text = message
	remaining = 4.5
	modulate.a = 0
	show()
func _process(delta: float) -> void:
	if remaining <= 0:
		hide()
		return
	remaining = maxf(0, remaining - delta)
	modulate.a = minf(minf((4.5 - remaining) / 0.2, remaining / 0.4), 1.0)
