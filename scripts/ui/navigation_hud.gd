class_name NavigationHUD
extends CanvasLayer

signal destination_requested(anchor_id: StringName)
signal resume_requested
signal quit_requested

var _buttons: Dictionary = {}

@onready var _location: Label = %Location
@onready var _message: Label = %Message
@onready var _prompt: Label = %Prompt
@onready var _destinations: HBoxContainer = %Destinations
@onready var _menu: Control = %Menu
@onready var _resume: Button = %Resume


func _ready() -> void:
	_resume.pressed.connect(func() -> void: resume_requested.emit())
	%Quit.pressed.connect(func() -> void: quit_requested.emit())


func configure(anchors: Array[AnchorPoint]) -> void:
	for child in _destinations.get_children():
		child.queue_free()
	_buttons.clear()
	for index in anchors.size():
		var anchor := anchors[index]
		var button := Button.new()
		button.text = "%d   %s" % [index + 1, anchor.display_name]
		button.custom_minimum_size = Vector2(185, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_request.bind(anchor.anchor_id))
		_destinations.add_child(button)
		_buttons[anchor.anchor_id] = button


func _request(anchor_id: StringName) -> void:
	destination_requested.emit(anchor_id)


func update_navigation(rig: AnchorCamera) -> void:
	var current := rig.get_anchor(rig.current_anchor_id)
	if current == null:
		return
	_location.text = current.display_name.to_upper()
	for id: StringName in _buttons:
		var button := _buttons[id] as Button
		button.disabled = not rig.can_move_to(id)
		if id == rig.current_anchor_id:
			button.tooltip_text = "Вы здесь"
		elif rig.is_transitioning:
			button.tooltip_text = "Дождитесь завершения перехода"
		elif not rig.can_move_to(id):
			button.tooltip_text = "Нет прямого перехода. Подойдите через соседнюю точку."
		else:
			button.tooltip_text = "Подойти: " + rig.get_anchor(id).display_name
	_message.text = "Переход…" if rig.is_transitioning else "Выберите доступную точку или наведите на её метку и нажмите E."


func set_prompt(prompt: String) -> void:
	_prompt.text = prompt


func show_notice(message: String) -> void:
	_message.text = message


func set_menu_visible(value: bool) -> void:
	_menu.visible = value
	if value:
		_resume.grab_focus()
	else:
		_resume.release_focus()
