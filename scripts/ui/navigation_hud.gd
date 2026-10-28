class_name NavigationHUD
extends CanvasLayer

signal destination_requested(anchor_id: StringName)
signal resume_requested
signal quit_requested
signal talk_requested
signal journal_requested
signal service_requested
signal new_game_requested
signal leave_workstation_requested

@onready var _notice = preload("res://scripts/ui/notice_bubble.gd").new()
var _buttons: Dictionary = {}
var _shift_number: int = 1
var _free_roam: bool = false
var _pointer_hint: bool = false
var _settings_open: bool = false

@onready var _location: Label = %Location
@onready var _message: Label = %Message
@onready var _prompt: Label = %Prompt
@onready var _destinations: HBoxContainer = %Destinations
@onready var _menu: Control = %Menu
@onready var _resume: Button = %Resume


func _ready() -> void:
	$Screen.add_child(_notice)
	_prompt.hide()
	for button in [%Resume, %OpenSettings, %SettingsBack, %Quit, %ResetPreferences, %ResetCamera, %NewGame]:
		button.custom_minimum_size = Vector2(300, 40)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	get_viewport().size_changed.connect(_layout_menu)
	_layout_menu()
	%OpenSettings.pressed.connect(func() -> void: show_settings(true))
	%SettingsBack.pressed.connect(func() -> void: show_settings(false))
	%LeaveWorkstation.pressed.connect(func() -> void: leave_workstation_requested.emit())
	_resume.pressed.connect(func() -> void: resume_requested.emit())
	%Quit.pressed.connect(func() -> void: quit_requested.emit())
	%Talk.pressed.connect(func() -> void: talk_requested.emit())
	%Journal.pressed.connect(func() -> void: journal_requested.emit())
	%Service.pressed.connect(func() -> void: service_requested.emit())
	%NewGame.pressed.connect(func() -> void: %ConfirmNewGame.popup_centered())
	%ConfirmNewGame.confirmed.connect(func() -> void: new_game_requested.emit())
	%Menu.visibility_changed.connect(func() -> void:
		if not %Menu.visible:
			%ConfirmNewGame.hide()
	)


func set_checkpoint_status(text: String) -> void:
	%CheckpointStatus.text = text


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
	if not prompt.is_empty():
		_notice.show_hint(prompt, "interact")


func show_notice(message: String) -> void:
	_message.text = message
	_notice.show_hint(message)
	if _free_roam:
		%MovementHint.text = message


func update_workstation(rig: FreeRoamCamera, exploration: bool, dialogue: bool = false) -> void:
	_free_roam = true
	if exploration and not rig.focus_active:
		_notice.show_hint("WASD — идти · E — взаимодействовать · J — дневник", "walk")
	$Screen/Actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	$Screen/Actions.offset_left = 24
	$Screen/Actions.offset_right = -24
	$Screen/Actions.offset_top = -105
	$Screen/Actions.offset_bottom = -61
	%ServiceStatus.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	%ServiceStatus.offset_left = 24
	%ServiceStatus.offset_right = -24
	%ServiceStatus.offset_top = -140
	%ServiceStatus.offset_bottom = -112
	$Screen/Bottom.hide()
	$Screen/Reticle.visible = exploration and not rig.focus_active
	%Prompt.visible = false
	_pointer_hint = exploration and rig.focus_active
	if not _pointer_hint:
		%Prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		%Prompt.offset_left = -280
		%Prompt.offset_right = 280
		%Prompt.offset_top = 30
		%Prompt.offset_bottom = 65
	$Screen/Actions.visible = exploration and rig.focus_active and not rig.is_transitioning
	%ServiceStatus.visible = $Screen/Actions.visible
	%LeaveWorkstation.visible = $Screen/Actions.visible
	%MovementHint.visible = false
	%MovementHint.text = ("Разговор продолжается · E — напитки · Esc — отойти" if dialogue else "Рабочая стойка у полок · E — напитки · T — разговор · Esc — отойти") if rig.focus_active else "WASD — идти · Мышь — обзор · E — взаимодействовать · J — дневник · Escape — меню"


func _process(_delta: float) -> void:
	%MovementHint.hide()
	%Prompt.hide()
	$Screen/Bottom.hide()
	if _pointer_hint and %Prompt.visible:
		%Prompt.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		%Prompt.size = Vector2(430, 35)
		var point := get_viewport().get_mouse_position() + Vector2(18, 24)
		%Prompt.position = point.clamp(Vector2(8, 8), ($Screen.size - %Prompt.size - Vector2(8, 8)).max(Vector2(8, 8)))


func show_settings(value: bool) -> void:
	_settings_open = value
	_layout_menu()
	%SettingsScroll.visible = value
	%SettingsBack.visible = value
	%OpenSettings.visible = not value
	%Resume.visible = not value
	%Quit.visible = not value
	$Screen/Menu/Center/Content/Caption.text = "НАСТРОЙКИ" if value else "ПАУЗА"
	if value:
		%SettingsBack.grab_focus()
	else:
		%OpenSettings.grab_focus()


func close_settings() -> bool:
	if not _settings_open:
		return false
	show_settings(false)
	return true


func set_menu_visible(value: bool) -> void:
	if value and not _menu.visible:
		show_settings(false)
	_menu.visible = value
	if value:
		_notice.hide()
	if value:
		_resume.grab_focus()
	else:
		_resume.release_focus()


func update_narrative(talk_available: bool, journal_available: bool, count: int, unread: int = 0) -> void:
	%Talk.disabled = not talk_available
	%Talk.tooltip_text = ("Подойдите ближе к посетителю." if _free_roam else "Подойдите к стойке, чтобы начать тестовый разговор.") if not talk_available else "Начать тестовый разговор"
	%Journal.disabled = not journal_available
	%Journal.text = "J   Дневник · %d" % count
	if unread > 0:
		%Journal.text += " (+%d)" % unread


func update_service(available: bool, served: bool, drink_title: String) -> void:
	%Service.disabled = not available
	%Service.tooltip_text = "Гость уже обслужен." if served else "Подойдите к стойке, чтобы выбрать напиток."
	%ServiceStatus.text = "Подано: " + drink_title if served else "[TEST] Гость у стойки ждёт напиток"


func update_shift(remaining: int, budget: int, number: int = 0) -> void:
	if number > 0:
		_shift_number = number
	%ShiftTime.text = "Смена %d · Время: %d / %d" % [_shift_number, remaining, budget]


func _layout_menu() -> void:
	var content := $Screen/Menu/Center/Content
	content.custom_minimum_size.x = 560 if _settings_open else 360
	%SettingsScroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 240, 180, 420)
