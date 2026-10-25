class_name JournalPanel
extends CanvasLayer

signal close_requested

@onready var screen: Control = $Screen
@onready var _entries: VBoxContainer = %Entries


func _ready() -> void:
	%Close.pressed.connect(func() -> void: close_requested.emit())


func render(journal: Journal, return_to_dialogue: bool) -> void:
	for child in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	var entries := journal.get_entries()
	%Count.text = "Записей: %d · В порядке получения" % entries.size()
	%Close.text = "Вернуться к разговору" if return_to_dialogue else "Вернуться в бар"
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "Здесь появятся новые слова, которые вы узнаете в разговорах."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_entries.add_child(empty)
	for entry in entries:
		var title := Label.new()
		title.text = entry.title
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", Color(0.92, 0.79, 0.56))
		_entries.add_child(title)
		var description := Label.new()
		description.text = entry.description
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_entries.add_child(description)
		_entries.add_child(HSeparator.new())


func set_open(value: bool) -> void:
	screen.visible = value
	if value:
		_focus_close.call_deferred()


func reset_scroll() -> void:
	%Scroll.scroll_vertical = 0


func _focus_close() -> void:
	if screen.visible:
		%Close.grab_focus()
