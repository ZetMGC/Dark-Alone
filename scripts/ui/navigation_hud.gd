class_name NavigationHUD
extends CanvasLayer

signal destination_requested(anchor_id: StringName)
signal resume_requested
signal quit_requested
signal talk_requested
signal journal_requested
signal service_requested

var _buttons: Dictionary = {}
var _shift_number: int = 1
var _notice_titles: PackedStringArray = []
var _notice_seconds: float = 0.0
var _notice_allowed: bool = true

@onready var _location: Label = %Location
@onready var _message: Label = %Message
@onready var _prompt: Label = %Prompt
@onready var _destinations: HBoxContainer = %Destinations
@onready var _menu: Control = %Menu
@onready var _resume: Button = %Resume


func _ready() -> void:
	_resume.pressed.connect(func() -> void: resume_requested.emit())
	%Quit.pressed.connect(func() -> void: quit_requested.emit())
	%Talk.pressed.connect(func() -> void: talk_requested.emit())
	%Journal.pressed.connect(func() -> void: journal_requested.emit())
	%Service.pressed.connect(func() -> void: service_requested.emit())


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


func update_narrative(talk_available: bool, journal_available: bool, count: int, unread: int = 0) -> void:
	%Talk.disabled = not talk_available
	%Talk.tooltip_text = "Подойдите к стойке, чтобы начать тестовый разговор." if not talk_available else "Начать [TEST] разговор. Завершение стоит 1 деление; прерывание бесплатно."
	%Journal.disabled = not journal_available
	%Journal.text = "J   Дневник · %d" % count
	if unread > 0:
		%Journal.text += " (+%d)" % unread


func update_service(available: bool, served: bool, drink_title: String) -> void:
	%Service.disabled = not available
	if served:
		%Service.tooltip_text = "Гость уже получил: " + drink_title
	elif available:
		%Service.tooltip_text = "Выбрать напиток. Подача стоит 1 деление; отмена бесплатна."
	else:
		%Service.tooltip_text = "Подойдите к стойке, чтобы выбрать напиток."
	%ServiceStatus.text = "Подано: " + drink_title if served else "[TEST] Гость у стойки ждёт напиток"


func update_shift(remaining: int, budget: int, number: int = 0) -> void:
	if number > 0:
		_shift_number = number
	%ShiftTime.text = "Смена %d · Время: %d / %d" % [_shift_number, remaining, budget]


func set_context(mode: StringName) -> void:
	var world := mode == &"exploration"
	for path: String in ["Heading", "MenuHint", "Reticle", "Prompt", "Bottom", "Actions", "ServiceStatus", "ShiftTime"]:
		get_node("Screen/" + path).visible = world
	_notice_allowed = mode in [&"exploration", &"dialogue", &"service", &"shift_complete"]
	if mode == &"journal":
		_notice_titles.clear()
		_notice_seconds = 0.0
	%JournalNotice.visible = _notice_allowed and _notice_seconds > 0.0


func update_objective(at_counter: bool, talked: bool, served: bool, transitioning: bool, counter_available: bool = true) -> void:
	if transitioning:
		return
	var goal := "Поговорите с гостем и подайте напиток."
	if talked and not served:
		goal = "Подайте гостю напиток, чтобы закончить смену."
	elif served and not talked:
		goal = "Поговорите с гостем, чтобы закончить смену."
	elif talked and served:
		goal = "Смена завершена."
	var route := "2 — за стойку. " if counter_available else "Пройдите к стойке через соседнюю точку. "
	_message.text = goal if at_counter else route + goal
	$Screen/Bottom/Margin/Content/Help.text = "T — разговор · B — напиток · J — дневник · Escape — меню" if at_counter else "ПКМ / стрелки — обзор · 1–4 — точки · Escape — управление и настройки"


func show_journal_notice(title: String) -> void:
	if title not in _notice_titles:
		_notice_titles.append(title)
	%JournalNoticeText.text = "Новая запись в дневнике · J — открыть" if _notice_titles.size() == 1 else "Новые записи: %d · J — открыть дневник" % _notice_titles.size()
	_notice_seconds = 5.0
	%JournalNotice.visible = _notice_allowed


func _process(delta: float) -> void:
	if not _notice_allowed or _notice_seconds <= 0.0:
		return
	_notice_seconds = maxf(0.0, _notice_seconds - delta)
	if _notice_seconds == 0.0:
		%JournalNotice.hide()
		_notice_titles.clear()
