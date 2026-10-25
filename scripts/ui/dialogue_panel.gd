class_name DialoguePanel
extends CanvasLayer

signal choice_requested(dialogue_id: StringName, node_id: StringName, choice_id: StringName)
signal finish_requested(dialogue_id: StringName, node_id: StringName)
signal cancel_requested
signal journal_requested

var _focus_target: Control

@onready var screen: Control = $Screen
@onready var _choices: VBoxContainer = %Choices
@onready var _finish: Button = %Finish


func _ready() -> void:
	%Journal.pressed.connect(func() -> void: journal_requested.emit())
	%Cancel.pressed.connect(func() -> void: cancel_requested.emit())


func render(runner: DialogueRunner, journal: Journal) -> void:
	var dialogue_id := runner.current_dialogue_id
	var node_id := runner.current_node_id
	var node := runner.get_current_node()
	%Title.text = runner.get_dialogue_title()
	%Speaker.text = node.get("speaker", "")
	%Text.text = node.get("text", "")
	%Scroll.scroll_vertical = 0
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	# Сначала дать прочитать реплику; Tab переводит фокус к вариантам.
	_focus_target = %Scroll
	for choice in runner.get_choices():
		var button := Button.new()
		button.text = choice.text
		button.custom_minimum_size.y = 48
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not choice.available
		button.pressed.connect(func() -> void:
			choice_requested.emit(dialogue_id, node_id, StringName(choice.id))
		)
		_choices.add_child(button)
		if not choice.available:
			var titles: PackedStringArray = []
			for id in choice.missing_terms:
				titles.append(str(journal.get_definition(StringName(id)).get("title", id)))
			var hint := Label.new()
			hint.text = "Нужны записи в дневнике: " + ", ".join(titles)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
			_choices.add_child(hint)
	_finish.visible = runner.is_terminal()
	for connection in _finish.pressed.get_connections():
		_finish.pressed.disconnect(connection.callable)
	_finish.pressed.connect(func() -> void: finish_requested.emit(dialogue_id, node_id))
	if screen.visible:
		focus_current.call_deferred()


func set_open(value: bool) -> void:
	if not value:
		var focused := screen.get_viewport().gui_get_focus_owner()
		if focused != null and screen.is_ancestor_of(focused):
			_focus_target = focused
	screen.visible = value
	if value:
		focus_current.call_deferred()


func focus_current() -> void:
	if screen.visible and is_instance_valid(_focus_target) and _focus_target.is_visible_in_tree():
		_focus_target.grab_focus()
