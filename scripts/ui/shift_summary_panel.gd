class_name ShiftSummaryPanel
extends CanvasLayer

signal restart_requested
signal journal_requested
signal quit_requested
signal home_requested


func _ready() -> void:
	%Restart.pressed.connect(func() -> void: restart_requested.emit())
	%Journal.pressed.connect(func() -> void: journal_requested.emit())
	%Quit.pressed.connect(func() -> void: quit_requested.emit())
	%GoHome.pressed.connect(func() -> void: home_requested.emit())


func set_home_available(value: bool) -> void:
	%GoHome.visible = value


func render(clock: ShiftClock, journal: Journal, service: GuestService) -> void:
	%Info.text = "Время исчерпано · Завершено действий: %d\nЗаписей в дневнике: %d" % [clock.get_events().size(), journal.get_entries().size()]
	%Guest.text = "Гостю подано: " + str(service.get_served_drink().get("title", "")) if service.served else "Гость остался без напитка."
	for child in %Events.get_children():
		%Events.remove_child(child)
		child.queue_free()
	for event in clock.get_events():
		var label := Label.new()
		var title := "Разговор завершён" if str(event.id).begins_with("dialogue:") else "Напиток подан"
		label.text = "%s · %d дел." % [title, event.time_cost]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		%Events.add_child(label)


func set_open(value: bool) -> void:
	$Screen.visible = value
	if value:
		_focus_content.call_deferred()


func _focus_content() -> void:
	if is_inside_tree() and $Screen.is_visible_in_tree():
		%Scroll.grab_focus()
