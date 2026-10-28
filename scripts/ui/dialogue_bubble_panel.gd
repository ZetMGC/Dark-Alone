class_name DialogueBubblePanel
extends DialoguePanel
## Позиция речи зависит от головы, ответы — от взгляда; правила диалога в Session.

@onready var _notice = preload("res://scripts/ui/notice_bubble.gd").new()
var bubble_enabled: bool = false
var _response_input_enabled: bool = true
var _service_overlay: bool = false
var _workbench_overlay: bool = false
@export var characters_per_second: float = 38.0
@export var speech_hold_seconds: float = 3.0
@export var speech_fade_seconds: float = 1.2
var _speech_idle: float = 0.0
var _speech_alpha: float = 1.0
var looking_at_speaker: bool = false
var edge_mode: bool = false
var selected_index: int = -1
var _camera: Camera3D
var _speaker: Node3D
var _runner: DialogueRunner
var _line_key: String = ""
var _choices_data: Array[Dictionary] = []
var _typed: float = 0.0
var _length: int = 0
var _terminal: bool = false
var _window_focused: bool = true
var _pages: Array[Dictionary] = []
var _page_index: int = 0
var _edge_side: int = 0
var _position_ready: bool = false
var _position_target := Vector2.ZERO


func _ready() -> void:
	super._ready()
	screen.add_child(_notice)


func set_response_input_enabled(enabled: bool) -> void:
	_response_input_enabled = enabled


func set_service_overlay(enabled: bool) -> void:
	_service_overlay = enabled


func set_workbench_overlay(enabled: bool) -> void:
	_workbench_overlay = enabled


func configure_speaker(camera: Camera3D, speaker: Node3D) -> void:
	_camera = camera
	_speaker = speaker


func render(runner: DialogueRunner, journal: Journal) -> void:
	if not bubble_enabled:
		super.render(runner, journal)
		return
	_runner = runner
	var key := str(runner.current_dialogue_id) + ":" + str(runner.current_node_id)
	var node := runner.get_current_node()
	var fresh := key != _line_key
	if fresh:
		_line_key = key
		%VoiceSpeaker.text = node.get("speaker", "")
		_pages = SpeechPaginator.paginate(str(node.get("text", "")), %VoiceText.get_theme_font("normal_font"), %VoiceText.get_theme_font("bold_font"), %VoiceText.get_theme_font_size("normal_font_size"), Vector2(minf(460, screen.size.x - 32) - 36, 112))
		_page_index = 0
		_show_page()
	_terminal = runner.is_terminal()
	# Индекс всегда относится к видимому списку; выбранная реплика переживает вставку новых по ID.
	var selected_id := str(_choices_data[selected_index].id) if not fresh and selected_index >= 0 and selected_index < _choices_data.size() else ""
	_choices_data = runner.get_choices().filter(func(choice: Dictionary) -> bool: return choice.available)
	selected_index = -1
	for index in _choices_data.size():
		if str(_choices_data[index].id) == selected_id:
			selected_index = index
			break
	if fresh or selected_index < 0 or selected_index >= _choices_data.size() or not _choices_data[selected_index].available:
		selected_index = -1
		for index in _choices_data.size():
			if _choices_data[index].available:
				selected_index = index
				break
	_rebuild_choices(journal)
	_update_layout()


func _rebuild_choices(_journal: Journal) -> void:
	for child in %VoiceChoices.get_children():
		%VoiceChoices.remove_child(child)
		child.queue_free()
	for index in _choices_data.size():
		var choice: Dictionary = _choices_data[index]
		var row = preload("res://scripts/ui/reply_choice_row.gd").new()
		%VoiceChoices.add_child(row)
		row.set_choice(str(choice.text), index, _choices_data.size(), index == selected_index, %VoiceText.get_theme_font("normal_font"))
	_refresh_selection()


func set_open(value: bool) -> void:
	if not bubble_enabled:
		super.set_open(value)
		return
	screen.visible = value
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Screen/Card.hide()
	$Screen/Shade.hide()
	%VoiceBubble.visible = value
	%VoiceReplies.visible = false
	%VoiceHint.visible = false
	if not value and _runner != null and not _runner.active:
		_line_key = ""
	if value:
		_update_layout()


func focus_current() -> void:
	if not bubble_enabled:
		super.focus_current()


func is_line_complete() -> bool:
	return _typed >= _length


func get_page_count() -> int:
	return _pages.size()


func get_page_index() -> int:
	return _page_index


func is_speech_complete() -> bool:
	return is_line_complete() and _page_index == _pages.size() - 1


func _show_page() -> void:
	_speech_idle = 0
	_speech_alpha = 1
	%VoiceBubble.modulate.a = 1
	if _pages[_page_index].literal:
		%VoiceText.clear()
		%VoiceText.add_text(_pages[_page_index].text)
	else:
		DialogueText.write(%VoiceText, _pages[_page_index].text)
	_length = %VoiceText.get_total_character_count()
	_typed = 0
	%VoiceText.visible_characters = 0
	%VoicePage.visible = _pages.size() > 1
	%VoicePage.text = "%d / %d" % [_page_index + 1, _pages.size()]


func advance_page() -> bool:
	if not _response_input_enabled or not screen.visible or not _window_focused or not is_line_complete() or _page_index >= _pages.size() - 1:
		return false
	_page_index += 1
	_show_page()
	_update_layout()
	return true


func reveal_text() -> void:
	if not _response_input_enabled or not screen.visible or not _window_focused:
		return
	_typed = _length
	%VoiceText.visible_characters = -1
	_update_layout()


func can_answer() -> bool:
	return _response_input_enabled and bubble_enabled and screen.visible and _window_focused and is_instance_valid(_camera) and is_instance_valid(_speaker) and looking_at_speaker and is_speech_complete() and _runner != null and _runner.active and _line_key == str(_runner.current_dialogue_id) + ":" + str(_runner.current_node_id)


func select_relative(direction: int) -> bool:
	_update_layout()
	if not can_answer() or _choices_data.is_empty() or direction not in [-1, 1]:
		return false
	for step in range(1, _choices_data.size() + 1):
		var index := posmod(selected_index + direction * step, _choices_data.size())
		if _choices_data[index].available:
			selected_index = index
			_refresh_selection()
			return true
	return false


func submit_choice(index: int) -> bool:
	_update_layout()
	if not can_answer() or index < 0 or index >= _choices_data.size() or not _choices_data[index].available:
		return false
	choice_requested.emit(_runner.current_dialogue_id, _runner.current_node_id, StringName(_choices_data[index].id))
	return true


func confirm() -> bool:
	_update_layout()
	if not _response_input_enabled or not screen.visible or not _window_focused:
		return false
	if not is_line_complete():
		reveal_text()
		return true
	if advance_page():
		return true
	if not can_answer():
		return false
	if _terminal:
		finish_requested.emit(_runner.current_dialogue_id, _runner.current_node_id)
		return true
	return submit_choice(selected_index)


func _refresh_selection() -> void:
	for index in %VoiceChoices.get_child_count():
		%VoiceChoices.get_child(index).set_selected(index == selected_index)


func _process(delta: float) -> void:
	if not bubble_enabled or not screen.visible:
		return
	if _window_focused and not is_line_complete():
		_typed = minf(_length, _typed + maxf(characters_per_second, 1.0) * delta)
		%VoiceText.visible_characters = int(_typed)
	if _window_focused and is_speech_complete():
		_speech_idle += delta
		_speech_alpha = 1.0 - clampf((_speech_idle - speech_hold_seconds) / maxf(speech_fade_seconds, 0.01), 0, 1)
	%VoiceBubble.modulate.a = _speech_alpha
	_update_layout()
	if _position_ready and _window_focused:
		%VoiceBubble.position = %VoiceBubble.position.lerp(_position_target, 1.0 - exp(-minf(delta, 0.05) / 0.16))


func _update_layout() -> void:
	if not bubble_enabled or not screen.visible:
		return
	if _runner == null or not _runner.active:
		%VoiceBubble.hide()
		%VoiceReplies.hide()
		%VoiceHint.hide()
		_position_ready = false
		_edge_side = 0
		return
	if not is_instance_valid(_camera) or not is_instance_valid(_speaker):
		looking_at_speaker = false
		%VoiceBubble.hide()
		%VoiceReplies.hide()
		return
	%VoiceBubble.visible = _speech_alpha > 0
	var head := _speaker.global_position + Vector3.UP * 0.36
	var face := _speaker.global_position + Vector3.UP * 0.06
	var area := screen.size
	# На плоскости камеры перспектива не определена; голос сразу уходит к краю.
	var head_local := _camera.to_local(head)
	var point := _camera.unproject_position(head) if head_local.z < -0.001 else Vector2(-10000, -10000)
	var local := _camera.to_local(face)
	var behind := _camera.is_position_behind(face)
	var visible_head := not behind and Rect2(Vector2.ZERO, area).has_point(point)
	var query := PhysicsRayQueryParameters3D.create(_camera.global_position, face, 1)
	var clear := _camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	looking_at_speaker = visible_head and clear and -_camera.global_basis.z.dot((_speaker.global_position - _camera.global_position).normalized()) >= cos(deg_to_rad(20))
	edge_mode = not visible_head or not clear
	var width := minf(460, area.x - 32)
	%VoiceText.custom_minimum_size.y = clampf(%VoiceText.get_content_height(), 24, 112)
	%VoiceBubble.size = Vector2(width, 0)
	var height: float = %VoiceBubble.size.y
	var target := point - Vector2(width * 0.5, height + 12)
	if edge_mode:
		# Небольшие повороты вокруг центра затылка не перебрасывают голос между краями.
		var threshold := maxf(0.12, local.length() * 0.18)
		if _edge_side == 0 or absf(local.x) > threshold:
			_edge_side = -1 if local.x < 0 else 1
	if _workbench_overlay:
		target = Vector2(area.x - width - 16, 84)
	elif edge_mode:
		target = Vector2(16 if _edge_side < 0 else area.x - width - 16, 170)
	_position_target = Vector2(clampf(target.x, 16, maxf(16, area.x - width - 16)), clampf(target.y, 16, maxf(16, area.y - height - 245)))
	if not _position_ready:
		%VoiceBubble.position = _position_target
		_position_ready = true
	%VoiceDirection.visible = edge_mode
	%VoiceDirection.text = ("↙ Голос позади слева · обернитесь" if _edge_side < 0 else "Голос позади справа ↘ · обернитесь") if behind else ("← Говорят слева" if _edge_side < 0 else "Говорят справа →")
	if not clear and not behind:
		%VoiceDirection.text = "Голос за преградой · посмотрите на говорящего"
	%VoiceTail.visible = not edge_mode
	%VoiceReplies.visible = can_answer() and not _terminal and not _choices_data.is_empty()
	var reply_rect := preload("res://scripts/ui/reply_panel_layout.gd").rect(%VoiceChoices, area)
	%VoiceReplies.offset_left = -reply_rect.size.x * 0.5
	%VoiceReplies.offset_right = reply_rect.size.x * 0.5
	%VoiceReplies.offset_top = -60 - reply_rect.size.y
	%VoiceReplies.offset_bottom = -60
	if %VoiceReplies.visible and selected_index >= 0 and selected_index < %VoiceChoices.get_child_count():
		(%VoiceChoices.get_parent() as ScrollContainer).ensure_control_visible(%VoiceChoices.get_child(selected_index))
	%VoiceReplyHelp.text = "E — закончить разговор" if _terminal else "1–9 — ответить · Колесо — выбор · E — подтвердить"
	%VoiceHint.text = "E — показать реплику целиком · J — дневник · Esc — меню" if not is_line_complete() else ("Посмотрите на говорящего, чтобы ответить" if not looking_at_speaker else "J — дневник · Esc — меню · Backspace — прервать")
	if is_line_complete() and not is_speech_complete():
		%VoiceHint.text = "E — следующий пузырёк · J — дневник · Esc — меню"
	if _terminal and can_answer():
		%VoiceHint.text = "E — закончить разговор · J — дневник"
	elif is_speech_complete() and looking_at_speaker and _choices_data.is_empty():
		%VoiceHint.text = "J — дневник · Backspace — прервать разговор"
	%VoiceHint.visible = false
	%VoiceReplyHelp.hide()
	if not _response_input_enabled:
		%VoiceHint.text = "Esc — отойти от стойки и продолжить разговор"

	if not _service_overlay:
		_notice.show_hint(%VoiceHint.text)


func _input(event: InputEvent) -> void:
	if not _response_input_enabled or not bubble_enabled or not screen.visible or not _window_focused or event.is_echo():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		select_relative(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_E:
			# E у доступного предмета остаётся взаимодействием даже во время речи.
			var interaction := get_parent().get_node_or_null("InteractionController") as InteractionController
			var target: Interactable3D = interaction.get_target() if interaction != null else null
			if is_instance_valid(target) and not target is DialogueTrigger and target.is_available():
				return
			confirm()
		elif key >= KEY_1 and key <= KEY_9:
			submit_choice(key - KEY_1)
		elif key == KEY_BACKSPACE:
			cancel_requested.emit()
		else:
			return
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true
