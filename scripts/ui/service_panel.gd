class_name ServicePanel
extends CanvasLayer

signal drink_requested(drink_id: StringName)
signal close_requested
signal menu_requested

var _focus_target: Control

@onready var screen: Control = $Screen


func _ready() -> void:
	%Close.pressed.connect(func() -> void: close_requested.emit())
	%Menu.pressed.connect(func() -> void: menu_requested.emit())


func render(service: GuestService) -> void:
	_focus_target = %Scroll
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
		button.custom_minimum_size.y = 52
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void: drink_requested.emit(StringName(option.id)))
		%Options.add_child(button)
		%Options.add_child(HSeparator.new())
	%Scroll.scroll_vertical = 0


func set_open(value: bool) -> void:
	if not value and screen.visible:
		var focused := screen.get_viewport().gui_get_focus_owner()
		if focused != null and screen.is_ancestor_of(focused):
			_focus_target = focused
	screen.visible = value
	if value:
		_focus_content.call_deferred()


func _focus_content() -> void:
	if is_inside_tree() and screen.is_visible_in_tree():
		if is_instance_valid(_focus_target) and _focus_target.is_visible_in_tree():
			_focus_target.grab_focus()
		else:
			%Scroll.grab_focus()
