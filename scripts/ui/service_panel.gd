class_name ServicePanel
extends CanvasLayer

signal drink_requested(drink_id: StringName)
signal preparation_requested(preparation: DrinkPreparation)
var preparation_stager: Callable
var workbench_enabled: bool = false
var workbench: DrinkWorkbench
signal close_requested
signal menu_requested

@onready var screen: Control = $Screen


func _ready() -> void:
	%Close.pressed.connect(func() -> void: close_requested.emit())
	%Menu.pressed.connect(func() -> void: menu_requested.emit())


func enable_workbench() -> void:
	if workbench != null:
		return
	workbench_enabled = true
	layer = 11
	workbench = DrinkWorkbench.new()
	workbench.name = "DrinkWorkbench"
	screen.add_child(workbench)
	workbench.preparation_requested.connect(func(value: DrinkPreparation) -> void:
		if preparation_stager.is_valid():
			if preparation_stager.call(value):
				workbench.mark_world_staged()
		else:
			preparation_requested.emit(value)
	)
	workbench.close_requested.connect(func() -> void: close_requested.emit())
	workbench.menu_requested.connect(func() -> void: menu_requested.emit())
	$Screen/Card.hide()
	$Screen/Shade.hide()


func set_conversation_context(active: bool) -> void:
	if workbench_enabled:
		return
	var card: Control = $Screen/Card
	card.anchor_left = 0.5 if active else 0.1
	card.anchor_top = 0.54 if active else 0.1
	card.anchor_right = 0.98 if active else 0.9
	card.anchor_bottom = 0.97 if active else 0.9
	$Screen/Shade.visible = not active
	var margin: MarginContainer = $Screen/Card/Margin
	margin.add_theme_constant_override("margin_left", 12 if active else 26)
	margin.add_theme_constant_override("margin_right", 12 if active else 26)
	margin.add_theme_constant_override("margin_top", 12 if active else 22)
	margin.add_theme_constant_override("margin_bottom", 12 if active else 22)
	$Screen/Card/Margin/Content.add_theme_constant_override("separation", 8 if active else 18)
	$Screen/Card/Margin/Content/Title.add_theme_font_size_override("font_size", 22 if active else 28)
	%Options.add_theme_constant_override("separation", 8 if active else 14)
	for child in %Options.get_children():
		if child is Button:
			child.custom_minimum_size.y = 44 if active else 52
		elif child is Label or child is HSeparator:
			child.visible = not active
	$Screen/Card/Margin/Content/Order.text = "Разговор продолжается. Что подать?" if active else "[TEST] Гость ждёт напиток. Что подать?"


func render(service: GuestService) -> void:
	for child in %Options.get_children():
		%Options.remove_child(child)
		child.queue_free()
	for option in service.get_options():
		var description := Label.new()
		description.text = option.description
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		%Options.add_child(description)
		var button := Button.new()
		button.text = "Подать: " + str(option.title)
		button.tooltip_text = str(option.description)
		button.custom_minimum_size.y = 52
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void: drink_requested.emit(StringName(option.id)))
		%Options.add_child(button)
		%Options.add_child(HSeparator.new())
	%Scroll.scroll_vertical = 0


func set_open(value: bool) -> void:
	screen.visible = value
	if workbench_enabled:
		workbench.set_active(value)
		return
	if value:
		_focus_content.call_deferred()


func _focus_content() -> void:
	if is_inside_tree() and screen.is_visible_in_tree():
		%Scroll.grab_focus()
