extends Node3D
## Композиция мира и нарративной сессии. Правила разговора живут в моделях.

const RUN_HANDOFF := &"dark_alone_journal_handoff"

@export_file("*.json") var glossary_path: String = "res://content/glossary/test_terms.json"
@export var dialogue_paths: PackedStringArray = ["res://content/dialogues/test_guest.json"]
@export_range(1, 24) var shift_budget: int = 2
@export var checkpoint_enabled: bool = true
@export var free_roam_enabled: bool = true
@export var drink_workbench_enabled: bool = true
@export var preferences_enabled: bool = true
var checkpoint_store := CheckpointStore.new()
var preference_store := PreferenceStore.new()
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
var _home: HomeExploration
var _checkpoint_message: String = ""
var _preferences: PreferenceController
var _preferences_handoff: bool = false
var _counter_target: WorkstationTarget


func _ready() -> void:
	# Режим перемещения переживает обычную смену и тестовый сброс.
	if get_tree().has_meta(RUN_HANDOFF):
		var context: Variant = get_tree().get_meta(RUN_HANDOFF)
		if context is Dictionary and context.get("scene") == scene_file_path and context.get("free_roam_enabled") is bool:
			free_roam_enabled = context.free_roam_enabled
		if context is Dictionary and context.get("scene") == scene_file_path and context.has("preferences_enabled"):
			if not context.preferences_enabled is bool or not context.get("preference_store") is PreferenceStore:
				_fail_setup("Неверная передача настроек игрока.")
				return
			preferences_enabled = context.preferences_enabled
			preference_store = context.preference_store
			_preferences_handoff = true
	if get_tree().has_meta(RUN_HANDOFF):
		var previous: Variant = get_tree().get_meta(RUN_HANDOFF)
		if previous is Dictionary and previous.get("scene") == scene_file_path and previous.get("drink_workbench_enabled") is bool:
			drink_workbench_enabled = previous.drink_workbench_enabled
	if free_roam_enabled and drink_workbench_enabled:
		($ServicePanel as ServicePanel).enable_workbench()
		_hud.get_node("%Service").text = "B   Готовить"
	(_rig as FreeRoamCamera).free_roam_enabled = free_roam_enabled
	_session.concurrent_service_enabled = free_roam_enabled
	($DialoguePanel as DialogueBubblePanel).bubble_enabled = free_roam_enabled
	($DialoguePanel as DialogueBubblePanel).configure_speaker(_rig.view, _trigger)
	(_rig as FreeRoamCamera).focus_anchor_ids = PackedStringArray(["back_counter"])
	(_rig as FreeRoamCamera).availability_changed.connect(_refresh_navigation)
	_hud.leave_workstation_requested.connect(func() -> void:
		if _session.mode in [NarrativeSession.EXPLORATION, NarrativeSession.DIALOGUE]:
			(_rig as FreeRoamCamera).leave_focus()
	)
	_hud.resume_requested.connect(_resume_menu)
	_hud.quit_requested.connect(func() -> void: get_tree().quit())
	if free_roam_enabled:
		var back := (load("res://scenes/levels/back_counter.tscn") as PackedScene).instantiate() as Node3D
		add_child(back)
		var anchor := (load("res://scenes/navigation/anchor_point.tscn") as PackedScene).instantiate() as AnchorPoint
		anchor.name = "BackCounter"
		anchor.anchor_id = &"back_counter"
		anchor.display_name = "Рабочая стойка у полок"
		_anchors_root.add_child(anchor)
		anchor.global_transform = back.get_node("WorkPosition").global_transform
	if not _rig.configure(_anchors_root, &"entry"):
		_fail_setup("Ошибка локации: " + "; ".join(_rig.validation_errors))
		return
	_configured = true
	_interaction.configure(_rig.view)
	if free_roam_enabled:
		_interaction.reach = 3.0
		_trigger.show_marker = false
		_counter_target = WorkstationTarget.new()
		_counter_target.name = "CounterTarget"
		_counter_target.collision_layer = 0
		_counter_target.collision_mask = 0
		_counter_target.monitoring = false
		add_child(_counter_target)
		_counter_target.activated.connect(_use_counter)
		for part in ["BackCounter/Top/Body", "BackCounter/Cabinet/Body", "BarLevel/Geometry/ShelfBack/Body", "BarLevel/Geometry/ShelfUpper/Body", "BarLevel/Geometry/ShelfLower/Body"]:
			var body := get_node_or_null(part) as CollisionObject3D
			if not _interaction.register_surface(body, _counter_target):
				_fail_setup("Не удалось связать поверхность стойки: " + part)
				return
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
	var shared_home: HomeState
	var number: int = 1
	var transferred: bool = false
	var save_on_ready: bool = false
	if get_tree().has_meta(RUN_HANDOFF):
		var handoff: Variant = get_tree().get_meta(RUN_HANDOFF)
		if not handoff is Dictionary or handoff.get("scene") != scene_file_path:
			_fail_setup("Не удалось восстановить дневник между сменами.")
			return
		if handoff.has("fresh") and not handoff.fresh is bool:
			_fail_setup("Неверный режим новой смены.")
			return
		if handoff.has("checkpoint_enabled"):
			if not handoff.checkpoint_enabled is bool or not handoff.get("checkpoint_store") is CheckpointStore:
				_fail_setup("Неверная передача хранилища автосохранения.")
				return
			checkpoint_enabled = handoff.checkpoint_enabled
			checkpoint_store = handoff.checkpoint_store
		if handoff.get("fresh", false) != true:
			if not handoff.get("journal") is Journal or not handoff.get("shift") is int or handoff.shift < 2:
				_fail_setup("Не удалось восстановить дневник между сменами.")
				return
			shared_journal = handoff.journal
			if handoff.has("home_state"):
				if not handoff.home_state is HomeState:
					_fail_setup("Не удалось восстановить исследование дома.")
					return
				shared_home = handoff.home_state
			number = handoff.shift
			save_on_ready = true
		transferred = true
		get_tree().remove_meta(RUN_HANDOFF)
	if checkpoint_enabled and not transferred:
		var checkpoint := checkpoint_store.load_checkpoint(catalog)
		if not checkpoint.is_empty():
			shared_journal = checkpoint.journal
			shared_home = checkpoint.home_state
			number = checkpoint.shift
			_checkpoint_message = "Продолжена игра с начала смены %d." % number
		if not checkpoint_store.last_error.is_empty():
			_checkpoint_message = checkpoint_store.last_error
	if not _session.configure(catalog, $DialoguePanel, $JournalPanel, $ServicePanel, _trigger.guest_id, drink_options, shared_journal, number):
		_fail_setup("Не удалось настроить разговор, дневник или меню напитков. " + "; ".join(_session.service.validation_errors))
		return
	if not _session.configure_shift(shift_budget, $ShiftSummaryPanel):
		_fail_setup("Не удалось настроить время смены.")
		return
	_home = (load("res://scenes/home/home_exploration.tscn") as PackedScene).instantiate() as HomeExploration
	_home.name = "HomeExploration"
	_home.position = Vector3(32, 0, 0)
	add_child(_home)
	if not _home.configure(_session, _hud, shared_home, free_roam_enabled):
		_fail_setup("Не удалось настроить дом.")
		return
	_home.work_requested.connect(_session.go_to_work)
	_home.journal_requested.connect(_session.open_journal)
	_rig.view.make_current()
	if not _session.configure_commute($CommutePanel, true):
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
	$JournalPanel.configure_controls(_hud)
	$DisplaySettings.configure_controls(_hud)
	$DialogueTrigger/Body.configure_controls(_hud)
	_rig.configure_controls(_hud)
	_preferences = PreferenceController.new()
	_preferences.name = "PreferenceController"
	add_child(_preferences)
	_preferences.configure(preference_store, $Presentation, _rig, $JournalPanel, $DisplaySettings, _hud, preferences_enabled, not _preferences_handoff)
	_hud.new_game_requested.connect(_new_game_from_menu)
	if checkpoint_enabled and save_on_ready:
		_checkpoint_message = "Автосохранение: начало смены %d." % number if checkpoint_store.save_checkpoint(number, _session.journal, _home.state, catalog) else checkpoint_store.last_error
	_update_checkpoint_label()
	if not _checkpoint_message.is_empty():
		_hud.show_notice(_checkpoint_message)


func _input(event: InputEvent) -> void:
	# Поиск дневника получает буквы J/T/B, не игровые горячие клавиши.
	if (get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit) and not event.is_action_pressed("toggle_menu"):
		return
	if is_instance_valid(_home) and _home.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_menu"):
		if _session.mode == NarrativeSession.MENU and _hud.close_settings():
			get_viewport().set_input_as_handled()
			return
		if free_roam_enabled and _narrative_ready and _session.mode in [NarrativeSession.EXPLORATION, NarrativeSession.DIALOGUE] and (_rig as FreeRoamCamera).leave_focus():
			get_viewport().set_input_as_handled()
			return
		if not _narrative_ready:
			_error_menu = not _error_menu
			_hud.set_menu_visible(_error_menu)
		elif _session.mode == NarrativeSession.MENU:
			_session.resume_menu()
		elif _session.mode == NarrativeSession.JOURNAL:
			_session.request_close_journal()
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
	if not _narrative_ready or (_session.mode != NarrativeSession.EXPLORATION and not (free_roam_enabled and _session.mode == NarrativeSession.DIALOGUE)):
		return
	if event.is_action_pressed("interact"):
		if not _interaction.try_interact() and not _rig.is_transitioning:
			_hud.show_notice("Наведите на стойку или посетителя и нажмите E." if free_roam_enabled else "Наведите прицел на метку или выберите доступную точку внизу.")
		get_viewport().set_input_as_handled()
	if free_roam_enabled:
		return
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
	if _preferences != null:
		_preferences.flush()
	if not keep_journal and checkpoint_enabled and not checkpoint_store.clear_checkpoint():
		_checkpoint_message = checkpoint_store.last_error
		_update_checkpoint_label()
		_hud.show_notice(checkpoint_store.last_error)
		return false
	_restart_pending = true
	var handoff := {"scene": scene_file_path, "checkpoint_enabled": checkpoint_enabled, "checkpoint_store": checkpoint_store, "fresh": not keep_journal, "free_roam_enabled": free_roam_enabled, "drink_workbench_enabled": drink_workbench_enabled, "preferences_enabled": preferences_enabled, "preference_store": preference_store}
	if keep_journal:
		handoff.merge({"journal": _session.journal, "home_state": _home.state, "shift": _session.shift_number + 1})
	get_tree().set_meta(RUN_HANDOFF, handoff)
	var result := get_tree().reload_current_scene()
	if result != OK:
		get_tree().remove_meta(RUN_HANDOFF)
		_restart_pending = false
	return result == OK


func _new_game_from_menu() -> void:
	if _narrative_ready and not _restart_pending and _session.mode == NarrativeSession.MENU and get_tree().current_scene == self:
		_reload_shift()


func _update_checkpoint_label() -> void:
	var text := "Автосохранение выполняется между сменами."
	if not checkpoint_enabled:
		text = "Автосохранение отключено для проверочного запуска."
	elif not _checkpoint_message.is_empty():
		text = _checkpoint_message
	_hud.set_checkpoint_status(text)


func _start_dialogue(dialogue_id: StringName) -> bool:
	if not _narrative_ready or _rig.is_transitioning or _session.mode != NarrativeSession.EXPLORATION:
		return false
	if (free_roam_enabled and not _guest_in_reach()) or (not free_roam_enabled and _rig.current_anchor_id != _trigger.required_anchor):
		_hud.show_notice("Подойдите ближе к посетителю." if free_roam_enabled else "Подойдите к стойке, чтобы начать [TEST] разговор.")
		return false
	var accepted := _session.start_dialogue(dialogue_id)
	if accepted and free_roam_enabled and (_rig as FreeRoamCamera).focus_active:
		(_rig as FreeRoamCamera).leave_focus()
	return accepted


func _guest_in_reach() -> bool:
	if not _rig.view.current or _rig.view.global_position.distance_to(_trigger.global_position) > 3.0:
		return false
	var query := PhysicsRayQueryParameters3D.create(_rig.view.global_position, _trigger.global_position, 1)
	return _rig.view.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _use_counter() -> void:
	if not _narrative_ready or _session.mode not in [NarrativeSession.EXPLORATION, NarrativeSession.DIALOGUE] or _rig.is_transitioning:
		return
	if (_rig as FreeRoamCamera).focus_active:
		open_service_menu()
	else:
		_rig.request_move(&"back_counter")


func _physics_process(_delta: float) -> void:
	if not free_roam_enabled or not _narrative_ready:
		return
	var ready := _session.mode == NarrativeSession.EXPLORATION and not _rig.is_transitioning and _guest_in_reach()
	if ready != _trigger.is_available():
		_refresh_navigation()


func _toggle_journal() -> void:
	if not _narrative_ready or _rig.is_transitioning:
		return
	if _session.mode == NarrativeSession.JOURNAL:
		_session.request_close_journal()
	else:
		_session.open_journal()


func open_service_menu() -> bool:
	if not _narrative_ready or _rig.is_transitioning or (_session.mode != NarrativeSession.EXPLORATION and not (free_roam_enabled and _session.mode == NarrativeSession.DIALOGUE)):
		return false
	if _rig.current_anchor_id != (&"back_counter" if free_roam_enabled else _trigger.required_anchor):
		_hud.show_notice("Подойдите к стойке, чтобы обслужить гостя.")
		return false
	if _session.service.served:
		_hud.show_notice("Гость уже получил напиток.")
		return false
	if not _session.can_open_service():
		_hud.show_notice("Осталось одно деление: сначала завершите или прервите разговор.")
		return false
	return _session.open_service()


func _on_service_completed(_event_id: StringName, _guest_id: StringName, _drink_id: StringName) -> void:
	var title := str(_session.service.get_served_drink().get("title", ""))
	_trigger.show_served(title)
	var prepared := _session.service.get_prepared_drink()
	if not prepared.is_empty():
		var counter: Node3D = $BarLevel/Geometry/CounterTop
		_trigger.show_prepared(prepared, counter.to_global(Vector3(0.25, 0.5, 0.1)))
	_refresh_navigation()
	_hud.show_notice("Напиток на стойке перед гостем. Esc — отойти и обернуться." if not prepared.is_empty() else "Гость получил: " + title)


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
	if free_roam_enabled and mode == NarrativeSession.EXPLORATION and (_rig as FreeRoamCamera).focus_active:
		_rig.reset_look()
	$Presentation.set_environment_context(mode)
	_hud.set_menu_visible(mode == NarrativeSession.MENU)
	_refresh_navigation()


func _refresh_navigation() -> void:
	if not _configured or not _narrative_ready:
		return
	var exploration := _session.mode == NarrativeSession.EXPLORATION
	var walking_dialogue := free_roam_enabled and _session.mode == NarrativeSession.DIALOGUE
	var focused := free_roam_enabled and (_rig as FreeRoamCamera).focus_active
	($DialoguePanel as DialogueBubblePanel).set_response_input_enabled(not focused and _session.mode == NarrativeSession.DIALOGUE)
	($DialoguePanel as DialogueBubblePanel).set_service_overlay(_session.mode == NarrativeSession.SERVICE)
	($DialoguePanel as DialogueBubblePanel).set_workbench_overlay(_session.mode == NarrativeSession.SERVICE and ($ServicePanel as ServicePanel).workbench_enabled)
	(_rig as FreeRoamCamera).set_dialogue_look(_session.mode == NarrativeSession.DIALOGUE and not focused)
	_rig.set_controls_enabled(exploration or walking_dialogue)
	var enabled := (exploration or walking_dialogue) and not _rig.is_transitioning
	_interaction.set_enabled(enabled)
	_interaction.pointer_mode = free_roam_enabled and enabled and (_rig as FreeRoamCamera).focus_active
	for anchor in _rig.get_anchors():
		anchor.set_available(not free_roam_enabled and _rig.can_move_to(anchor.anchor_id))
	_trigger.set_available(exploration and enabled and (_guest_in_reach() if free_roam_enabled else _rig.current_anchor_id == _trigger.required_anchor))
	if _counter_target != null:
		_counter_target.available = enabled and (_session.can_open_service() if focused else _rig.can_move_to(&"back_counter"))
		_counter_target.prompt = ("E — готовить напиток" if drink_workbench_enabled else "E — выбрать напиток") if focused else "E — открыть рабочую стойку у полок"
		_counter_target.blocked_prompt = ("Гость уже обслужен" if _session.service.served else "Осталось одно деление: сначала завершите разговор") if focused else "Подойдите к рабочей стойке у полок"
	_hud.update_navigation(_rig)
	_hud.update_narrative(_trigger.is_available(), enabled, _session.journal.get_known_term_ids().size(), _session.journal.get_unread_count())
	_hud.update_service(enabled and _session.can_open_service() and _rig.current_anchor_id == (&"back_counter" if free_roam_enabled else _trigger.required_anchor) and not _session.service.served, _session.service.served, str(_session.service.get_served_drink().get("title", "")))
	if free_roam_enabled:
		_hud.update_workstation(_rig as FreeRoamCamera, exploration or walking_dialogue, walking_dialogue)


func _fail_setup(message: String) -> void:
	_rig.set_controls_enabled(false)
	_interaction.set_enabled(false)
	_trigger.set_available(false)
	_hud.update_narrative(false, false, 0)
	_hud.update_service(false, false, "")
	_hud.show_notice(message)
	push_error(message)
