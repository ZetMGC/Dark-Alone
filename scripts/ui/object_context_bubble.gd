extends Control
## Сведения и действия существуют лишь пока прицел держится на предмете.
var interaction: InteractionController
var camera: Camera3D
var target: Interactable3D
var enabled: bool = true
var selected: int = 0
var actions: Array[Dictionary] = []
var text_label: Label
var info_panel: PanelContainer
var action_panel: PanelContainer
var choices: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_panel = PanelContainer.new()
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.custom_minimum_size.x = 280
	info_panel.add_theme_stylebox_override("panel", preload("res://scenes/ui/context_bubble_style.tres"))
	add_child(info_panel)
	action_panel = PanelContainer.new()
	action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_panel.add_theme_stylebox_override("panel", preload("res://scenes/ui/context_actions_style.tres"))
	add_child(action_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_panel.add_child(scroll)
	choices = VBoxContainer.new()
	choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 8)
	scroll.add_child(choices)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_font_size_override("font_size", 16)
	text_label.add_theme_color_override("font_color", Color(0.86, 0.85, 0.79))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial", "Noto Sans", "DejaVu Sans"])
	font.multichannel_signed_distance_field = true
	text_label.add_theme_font_override("font", font)
	info_panel.add_child(text_label)
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
	if lines.is_empty() and actions.is_empty():
		clear_context()
		return
	var world := target.context_anchor.global_position if is_instance_valid(target.context_anchor) else interaction.hit_position
	var viewport_size := get_viewport_rect().size
	var point := camera.unproject_position(world)
	if camera.is_position_behind(world) or not Rect2(Vector2.ZERO, viewport_size).has_point(point):
		clear_context()
		return
	text_label.text = "\n".join(lines)
	info_panel.visible = not lines.is_empty()
	info_panel.size = Vector2(280, 0)
	info_panel.position = (point + Vector2(20, -info_panel.size.y * 0.5)).clamp(Vector2(12, 12), (viewport_size - info_panel.size - Vector2(12, 12)).max(Vector2(12, 12)))
	_update_actions(viewport_size)
	show()

func _update_actions(area: Vector2) -> void:
	while choices.get_child_count() > actions.size():
		var last := choices.get_child(choices.get_child_count() - 1)
		choices.remove_child(last)
		last.queue_free()
	while choices.get_child_count() < actions.size():
		var row = preload("res://scripts/ui/reply_choice_row.gd").new()
		var index := choices.get_child_count()
		row.hovered.connect(func() -> void: selected = index)
		row.activated.connect(func() -> void: _activate_choice(index))
		choices.add_child(row)
	for index in actions.size():
		choices.get_child(index).set_choice(str(actions[index].text), index, actions.size(), index == selected, null, 17)
	action_panel.visible = not actions.is_empty()
	var reply_rect := preload("res://scripts/ui/reply_panel_layout.gd").rect(choices, area)
	action_panel.size = reply_rect.size
	action_panel.position = reply_rect.position


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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return _activate_choice(selected) if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else false
	if event is InputEventKey and event.pressed:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_E:
			return _activate_choice(selected)
	return false

func _activate_choice(index: int) -> bool:
	if not enabled or not is_visible_in_tree() or not is_instance_valid(target) or interaction.get_target() != target or not target.is_available() or index < 0 or index >= actions.size():
		clear_context()
		return false
	return target.activate_context_action(StringName(actions[index].id))
