extends PanelContainer
## Сведения и действия существуют лишь пока прицел держится на предмете.
var interaction: InteractionController
var camera: Camera3D
var target: Interactable3D
var enabled: bool = true
var selected: int = 0
var actions: Array[Dictionary] = []
var text_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	custom_minimum_size.x = 280
	add_theme_stylebox_override("panel", preload("res://scenes/ui/context_bubble_style.tres"))
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_font_size_override("font_size", 16)
	text_label.add_theme_color_override("font_color", Color(0.86, 0.85, 0.79))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial", "Noto Sans", "DejaVu Sans"])
	font.multichannel_signed_distance_field = true
	text_label.add_theme_font_override("font", font)
	add_child(text_label)
	hide()

func configure(controller: InteractionController, view: Camera3D) -> void:
	interaction = controller
	camera = view

func _process(_delta: float) -> void:
	refresh_context()

func refresh_context() -> void:
	if not enabled or not is_instance_valid(interaction) or not is_instance_valid(camera) or not camera.is_current():
		clear_context()
		return
	var current := interaction.get_target()
	if not is_instance_valid(current) or not current.is_available():
		clear_context()
		return
	if current != target:
		if is_instance_valid(target):
			target.context_feedback = ""
		selected = 0
	target = current
	actions.assign(target.get_context_actions())
	selected = clampi(selected, 0, maxi(0, actions.size() - 1))
	var lines: PackedStringArray = []
	if not target.context_title.is_empty():
		lines.append(target.context_title)
	if not target.context_description.is_empty():
		lines.append(target.context_description)
	if not target.context_feedback.is_empty():
		lines.append(target.context_feedback)
	for index in actions.size():
		lines.append(("› " if index == selected else "   ") + "%d  %s" % [index + 1, actions[index].text])
	if lines.is_empty():
		clear_context()
		return
	var world := target.context_anchor.global_position if is_instance_valid(target.context_anchor) else interaction.hit_position
	var viewport_size := get_viewport_rect().size
	var point := camera.unproject_position(world)
	if camera.is_position_behind(world) or not Rect2(Vector2.ZERO, viewport_size).has_point(point):
		clear_context()
		return
	text_label.text = "\n".join(lines)
	size = Vector2(280, 0)
	position = (point + Vector2(20, -size.y * 0.5)).clamp(Vector2(12, 12), (viewport_size - size - Vector2(12, 12)).max(Vector2(12, 12)))
	show()

func clear_context() -> void:
	if is_instance_valid(target):
		target.context_feedback = ""
	hide()
	target = null
	actions.clear()
	selected = 0

func handle_input(event: InputEvent) -> bool:
	if not enabled or not is_visible_in_tree() or actions.is_empty() or event.is_echo():
		return false
	# Нельзя выполнить действие прежней цели после отведения взгляда.
	if not is_instance_valid(target) or interaction.get_target() != target or not target.is_available():
		clear_context()
		return false
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		selected = posmod(selected + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1), actions.size())
		return true
	if event is InputEventKey and event.pressed:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var index := selected if key == KEY_F else int(key - KEY_1)
		if key != KEY_F and (key < KEY_1 or key > KEY_9):
			return false
		if index < 0 or index >= actions.size():
			return false
		return target.activate_context_action(StringName(actions[index].id))
	return false
