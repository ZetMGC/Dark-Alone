extends Node3D
## Композиция мира и нарративной сессии. Правила разговора живут в моделях.

const RUN_HANDOFF := &"dark_alone_journal_handoff"

@export_file("*.json") var glossary_path: String = "res://content/glossary/test_terms.json"
@export var dialogue_paths: PackedStringArray = ["res://content/dialogues/test_guest.json"]
@export_range(1, 24) var shift_budget: int = 2
@export var drink_options: Array[Dictionary] = [
	{"id": "test_water", "title": "[TEST] Вода", "description": "Стакан прохладной воды."},
	{"id": "test_house_drink", "title": "[TEST] Напиток бара", "description": "Напиток бара в простом стакане."}
]

@onready var _rig: AnchorCamera = $AnchorCamera
@onready var _interaction: InteractionController = $InteractionController
@onready var _hud: NavigationHUD = $NavigationHUD
@onready var _anchors_root: Node3D = $BarLevel/Anchors
@onready var _session: NarrativeSession = $NarrativeSession
@onready var _trigger: ServiceGuest = $DialogueTrigger

var _configured: bool = false
var _narrative_ready: bool = false
var _error_menu: bool = false
var _restart_pending: bool = false


func _ready() -> void:
	_hud.resume_requested.connect(_resume_menu)
	_hud.quit_requested.connect(func() -> void: get_tree().quit())
	if not _rig.configure(_anchors_root, &"entry"):
		_fail_setup("Ошибка локации: " + "; ".join(_rig.validation_errors))
		return
	_configured = true
	_interaction.configure(_rig.view)
	_interaction.prompt_changed.connect(_hud.set_prompt)
	_hud.configure(_rig.get_anchors())
	_hud.destination_requested.connect(_request_destination)
	_hud.talk_requested.connect(start_test_dialogue)
	_hud.journal_requested.connect(_toggle_journal)
	_hud.service_requested.connect(open_service_menu)
	_rig.transition_started.connect(_on_transition_started)
	_rig.anchor_reached.connect(_on_anchor_reached)
	for anchor in _rig.get_anchors():
		anchor.move_requested.connect(_move_to)
	var catalog := DialogueCatalog.new()
	if not catalog.load_files(glossary_path, dialogue_paths):
		_fail_setup("Ошибка контента: " + "; ".join(catalog.validation_errors))
		return
	if not catalog.has_dialogue(_trigger.dialogue_id) or _rig.get_anchor(_trigger.required_anchor) == null:
		_fail_setup("Ошибка цели разговора: неизвестный диалог или якорь.")
		return
	var shared_journal: Journal
	var number: int = 1
	if get_tree().has_meta(RUN_HANDOFF):
		var handoff: Variant = get_tree().get_meta(RUN_HANDOFF)
		if not handoff is Dictionary or handoff.get("scene") != scene_file_path or not handoff.get("journal") is Journal or not handoff.get("shift") is int or handoff.shift < 2:
			_fail_setup("Не удалось восстановить дневник между сменами.")
			return
		shared_journal = handoff.journal
		number = handoff.shift
		get_tree().remove_meta(RUN_HANDOFF)
	if not _session.configure(catalog, $DialoguePanel, $JournalPanel, $ServicePanel, _trigger.guest_id, drink_options, shared_journal, number):
		_fail_setup("Не удалось настроить разговор, дневник или меню напитков. " + "; ".join(_session.service.validation_errors))
		return
	if not _session.configure_shift(shift_budget, $ShiftSummaryPanel):
		_fail_setup("Не удалось настроить время смены.")
		return
	if not _session.configure_commute($CommutePanel):
		_fail_setup("Не удалось настроить переход между сменами.")
		return
	$ShiftSummaryPanel.restart_requested.connect(restart_shift)
	_session.new_shift_requested.connect(_restart_after_commute)
	$ShiftSummaryPanel.quit_requested.connect(func() -> void: get_tree().quit())
	_session.shift_progress_changed.connect(_hud.update_shift)
	_hud.update_shift(_session.shift.remaining, _session.shift.budget, _session.shift_number)
	_narrative_ready = true
	_session.mode_changed.connect(_on_mode_changed)
	_session.journal_changed.connect(func(_count: int) -> void: _refresh_navigation())
	_session.service_completed.connect(_on_service_completed)
	_trigger.dialogue_requested.connect(_start_dialogue)
	_refresh_navigation()
	$Presentation.configure_controls(_hud)


func _input(event: InputEvent) -> void:
	# Поиск дневника получает буквы J/T/B, не игровые горячие клавиши.
	if get_viewport().gui_get_focus_owner() is LineEdit and not event.is_action_pressed("toggle_menu"):
		return
	if event.is_action_pressed("toggle_menu"):
		if not _narrative_ready:
			_error_menu = not _error_menu
			_hud.set_menu_visible(_error_menu)
		elif _session.mode == NarrativeSession.MENU:
			_session.resume_menu()
		elif _session.mode == NarrativeSession.JOURNAL:
			_session.close_journal()
		elif _session.mode == NarrativeSession.SERVICE:
			_session.close_service()
		else:
			_session.open_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_journal"):
		_toggle_journal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("talk"):
		start_test_dialogue()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("serve"):
		open_service_menu()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _narrative_ready or _session.mode != NarrativeSession.EXPLORATION:
		return
	if event.is_action_pressed("interact"):
		if not _interaction.try_interact() and not _rig.is_transitioning:
			_hud.show_notice("Наведите прицел на метку или выберите доступную точку внизу.")
		get_viewport().set_input_as_handled()
	for index in _rig.get_anchors().size():
		if event.is_action_pressed("anchor_%d" % [index + 1]):
			_request_destination(_rig.get_anchors()[index].anchor_id)
			get_viewport().set_input_as_handled()
			return


func start_test_dialogue() -> bool:
	return _start_dialogue(_trigger.dialogue_id)


func restart_shift() -> bool:
	if not _narrative_ready or _restart_pending or _session.mode != NarrativeSession.SHIFT_COMPLETE or get_tree().current_scene != self:
		return false
	return _reload_shift()


func _restart_after_commute() -> void:
	if _narrative_ready and not _restart_pending and _session.mode == NarrativeSession.TRAVEL and _session.commute.state == CommuteFlow.READY and get_tree().current_scene == self:
		_reload_shift(true)


func _reload_shift(keep_journal: bool = false) -> bool:
	if get_tree().has_meta(RUN_HANDOFF):
		return false
	_restart_pending = true
	if keep_journal:
		get_tree().set_meta(RUN_HANDOFF, {"scene": scene_file_path, "journal": _session.journal, "shift": _session.shift_number + 1})
	var result := get_tree().reload_current_scene()
	if result != OK:
		if keep_journal:
			get_tree().remove_meta(RUN_HANDOFF)
		_restart_pending = false
	return result == OK


func _start_dialogue(dialogue_id: StringName) -> bool:
	if not _narrative_ready or _rig.is_transitioning or _session.mode != NarrativeSession.EXPLORATION:
		return false
	if _rig.current_anchor_id != _trigger.required_anchor:
		_hud.show_notice("Подойдите к стойке, чтобы начать [TEST] разговор.")
		return false
	return _session.start_dialogue(dialogue_id)


func _toggle_journal() -> void:
	if not _narrative_ready or _rig.is_transitioning:
		return
	if _session.mode == NarrativeSession.JOURNAL:
		_session.close_journal()
	else:
		_session.open_journal()


func open_service_menu() -> bool:
	if not _narrative_ready or _rig.is_transitioning or _session.mode != NarrativeSession.EXPLORATION:
		return false
	if _rig.current_anchor_id != _trigger.required_anchor:
		_hud.show_notice("Подойдите к стойке, чтобы обслужить гостя.")
		return false
	if _session.service.served:
		_hud.show_notice("Гость уже получил напиток.")
		return false
	return _session.open_service()


func _on_service_completed(_event_id: StringName, _guest_id: StringName, _drink_id: StringName) -> void:
	var title := str(_session.service.get_served_drink().get("title", ""))
	_trigger.show_served(title)
	_refresh_navigation()
	_hud.show_notice("Гость получил: " + title)


func _resume_menu() -> void:
	if _narrative_ready:
		_session.resume_menu()
	else:
		_error_menu = false
		_hud.set_menu_visible(false)


func _request_destination(anchor_id: StringName) -> void:
	if not _configured or not _narrative_ready or _session.mode != NarrativeSession.EXPLORATION:
		return
	if not _interaction.activate(_rig.get_anchor(anchor_id)):
		if _rig.is_transitioning:
			_hud.show_notice("Дождитесь завершения перехода.")
		elif anchor_id == _rig.current_anchor_id:
			_hud.show_notice("Вы уже в этой точке.")
		else:
			_hud.show_notice("Нет прямого перехода. Выберите одну из доступных соседних точек.")


func _move_to(anchor_id: StringName) -> void:
	_rig.request_move(anchor_id)


func _on_transition_started(_from_id: StringName, _to_id: StringName) -> void:
	_refresh_navigation()


func _on_anchor_reached(_anchor_id: StringName) -> void:
	_refresh_navigation()


func _on_mode_changed(mode: StringName) -> void:
	_hud.set_menu_visible(mode == NarrativeSession.MENU)
	_refresh_navigation()


func _refresh_navigation() -> void:
	if not _configured or not _narrative_ready:
		return
	var exploration := _session.mode == NarrativeSession.EXPLORATION
	_rig.set_controls_enabled(exploration)
	var enabled := exploration and not _rig.is_transitioning
	_interaction.set_enabled(enabled)
	for anchor in _rig.get_anchors():
		anchor.set_available(_rig.can_move_to(anchor.anchor_id))
	_trigger.set_available(enabled and _rig.current_anchor_id == _trigger.required_anchor)
	_hud.update_navigation(_rig)
	_hud.update_narrative(_trigger.is_available(), enabled, _session.journal.get_known_term_ids().size(), _session.journal.get_unread_count())
	_hud.update_service(enabled and _rig.current_anchor_id == _trigger.required_anchor and not _session.service.served, _session.service.served, str(_session.service.get_served_drink().get("title", "")))


func _fail_setup(message: String) -> void:
	_rig.set_controls_enabled(false)
	_interaction.set_enabled(false)
	_trigger.set_available(false)
	_hud.update_narrative(false, false, 0)
	_hud.update_service(false, false, "")
	_hud.show_notice(message)
	push_error(message)
