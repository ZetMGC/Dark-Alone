class_name NarrativeSession
extends Node
## Владеет моделями и порядком модальных экранов. Камеру связывает Main.

signal mode_changed(mode: StringName)
signal journal_changed(count: int)
signal service_completed(event_id: StringName, guest_id: StringName, drink_id: StringName)
signal shift_progress_changed(remaining: int, budget: int)
signal new_shift_requested

const EXPLORATION := &"exploration"
const DIALOGUE := &"dialogue"
const JOURNAL := &"journal"
const MENU := &"menu"
const SERVICE := &"service"
const SHIFT_COMPLETE := &"shift_complete"
const TRAVEL := &"travel"
const HOME := &"home"

var mode: StringName:
	get: return _mode
var runner := DialogueRunner.new()
var journal := Journal.new()
var service := GuestService.new()
var shift := ShiftClock.new()
var commute := CommuteFlow.new()

var _mode: StringName = EXPLORATION
var _journal_return: StringName = EXPLORATION
var _menu_return: StringName = EXPLORATION
var _dialogue_panel: DialoguePanel
var _journal_panel: JournalPanel
var _service_panel: ServicePanel
var _service_ready: bool = false
var _configured: bool = false
var _changing: bool = false
var _shift_ready: bool = false
var _summary_panel: ShiftSummaryPanel
var _run_serial: int = 0
var _active_run_id: StringName = &""
var _commute_panel: CommutePanel


func configure(catalog: DialogueCatalog, dialogue_panel: DialoguePanel, journal_panel: JournalPanel, service_panel: ServicePanel = null, guest_id: StringName = &"", drink_options: Array[Dictionary] = []) -> bool:
	if _configured or dialogue_panel == null or journal_panel == null or catalog == null or not catalog.is_loaded():
		return false
	if service_panel != null and not service.configure(guest_id, drink_options):
		return false
	if not journal.configure(catalog) or not runner.configure(catalog, journal):
		return false
	_dialogue_panel = dialogue_panel
	_journal_panel = journal_panel
	_service_panel = service_panel
	_service_ready = service_panel != null
	if _service_ready:
		_service_panel.drink_requested.connect(serve_drink)
		_service_panel.close_requested.connect(close_service)
		_service_panel.menu_requested.connect(open_menu)
		service.service_completed.connect(_on_service_completed)
	_dialogue_panel.choice_requested.connect(choose_for_node)
	_dialogue_panel.finish_requested.connect(finish_for_node)
	_dialogue_panel.cancel_requested.connect(cancel_dialogue)
	_dialogue_panel.journal_requested.connect(open_journal)
	_journal_panel.close_requested.connect(close_journal)
	runner.node_changed.connect(_on_node_changed)
	runner.dialogue_finished.connect(_on_dialogue_finished)
	runner.dialogue_cancelled.connect(_on_dialogue_closed)
	journal.term_added.connect(_on_term_added)
	_configured = true
	_sync_panels()
	return true


func configure_shift(time_budget: int, summary_panel: ShiftSummaryPanel) -> bool:
	if not _configured or _shift_ready or summary_panel == null or _mode != EXPLORATION or runner.active or service.served or not journal.get_entries().is_empty():
		return false
	if not shift.configure(time_budget):
		return false
	_summary_panel = summary_panel
	_summary_panel.journal_requested.connect(open_journal)
	shift.progress_changed.connect(func(left: int, total: int) -> void: shift_progress_changed.emit(left, total))
	shift.shift_finished.connect(_on_shift_finished)
	_shift_ready = true
	_sync_panels()
	return true


func configure_commute(panel: CommutePanel) -> bool:
	if not _shift_ready or _commute_panel != null or panel == null or _mode != EXPLORATION or _run_serial != 0 or service.served:
		return false
	_commute_panel = panel
	_summary_panel.set_home_available(true)
	_summary_panel.home_requested.connect(go_home)
	panel.arrived.connect(finish_commute)
	panel.work_requested.connect(go_to_work)
	panel.journal_requested.connect(open_journal)
	_sync_panels()
	return true


func go_home() -> bool:
	if _commute_panel == null or _changing or _mode != SHIFT_COMPLETE:
		return false
	_changing = true
	var accepted := commute.start_home()
	if accepted:
		_commute_panel.begin_trip(commute.trip_id, true)
		_set_mode(TRAVEL)
	_changing = false
	return accepted


func go_to_work() -> bool:
	if _commute_panel == null or _changing or _mode != HOME:
		return false
	_changing = true
	var accepted := commute.start_work()
	if accepted:
		_commute_panel.begin_trip(commute.trip_id, false)
		_set_mode(TRAVEL)
	_changing = false
	return accepted


func finish_commute(trip_id: int) -> bool:
	if _commute_panel == null or _changing or _mode != TRAVEL:
		return false
	_changing = true
	var accepted := commute.complete(trip_id)
	if accepted:
		_commute_panel.stop_trip()
		if commute.state == CommuteFlow.AT_HOME:
			_commute_panel.show_home()
			_set_mode(HOME)
		else:
			new_shift_requested.emit()
	_changing = false
	return accepted


func start_dialogue(dialogue_id: StringName) -> bool:
	if not _configured or _changing or _mode != EXPLORATION:
		return false
	_changing = true
	var accepted := runner.start(dialogue_id)
	if accepted:
		_run_serial += 1
		_active_run_id = StringName("dialogue:%s:%d" % [dialogue_id, _run_serial])
		_set_mode(DIALOGUE)
	_changing = false
	return accepted


func choose_for_node(dialogue_id: StringName, node_id: StringName, choice_id: StringName) -> bool:
	if not _accept_node_command(dialogue_id, node_id):
		return false
	_changing = true
	var accepted := runner.choose(choice_id)
	_changing = false
	return accepted


func finish_for_node(dialogue_id: StringName, node_id: StringName) -> bool:
	if not _accept_node_command(dialogue_id, node_id):
		return false
	_changing = true
	var accepted := runner.finish()
	_changing = false
	return accepted


func cancel_dialogue() -> bool:
	if not _configured or _changing or _mode != DIALOGUE:
		return false
	_changing = true
	var accepted := runner.cancel()
	_changing = false
	return accepted


func open_journal() -> bool:
	if not _configured or _changing or _mode not in [EXPLORATION, DIALOGUE, SHIFT_COMPLETE, HOME]:
		return false
	_changing = true
	_journal_return = _mode
	_journal_panel.render(journal, _journal_return == DIALOGUE, _journal_return == SHIFT_COMPLETE, _journal_return == HOME)
	_journal_panel.reset_scroll()
	_set_mode(JOURNAL)
	_changing = false
	return true


func close_journal() -> bool:
	if not _configured or _changing or _mode != JOURNAL:
		return false
	_changing = true
	_set_mode(_journal_return)
	_changing = false
	return true


func open_menu() -> bool:
	if not _configured or _changing or _mode == MENU:
		return false
	_changing = true
	_menu_return = _mode
	_set_mode(MENU)
	_changing = false
	return true


func open_service() -> bool:
	if not _configured or not _service_ready or _changing or _mode != EXPLORATION or service.served:
		return false
	_changing = true
	_service_panel.render(service)
	_set_mode(SERVICE)
	_changing = false
	return true


func close_service() -> bool:
	if not _configured or _changing or _mode != SERVICE:
		return false
	_changing = true
	_set_mode(EXPLORATION)
	_changing = false
	return true


func serve_drink(drink_id: StringName) -> bool:
	if not _configured or not _service_ready or _changing or _mode != SERVICE:
		return false
	_changing = true
	var accepted := service.serve(drink_id)
	_changing = false
	return accepted


func _on_service_completed(event_id: StringName, guest_id: StringName, drink_id: StringName) -> void:
	if _shift_ready:
		shift.apply_completed_event(event_id, 1)
	if _mode != SHIFT_COMPLETE:
		_set_mode(EXPLORATION)
	service_completed.emit(event_id, guest_id, drink_id)


func resume_menu() -> bool:
	if not _configured or _changing or _mode != MENU:
		return false
	_changing = true
	_set_mode(_menu_return)
	_changing = false
	return true


func _accept_node_command(dialogue_id: StringName, node_id: StringName) -> bool:
	return _configured and not _changing and _mode == DIALOGUE and runner.active \
		and runner.current_dialogue_id == dialogue_id and runner.current_node_id == node_id


func _on_node_changed(_dialogue_id: StringName, _node_id: StringName) -> void:
	_dialogue_panel.render(runner, journal)


func _on_dialogue_closed(_dialogue_id: StringName) -> void:
	_active_run_id = &""
	if _mode != SHIFT_COMPLETE:
		_set_mode(EXPLORATION)


func _on_dialogue_finished(_dialogue_id: StringName) -> void:
	var completed_id := _active_run_id
	_active_run_id = &""
	if _shift_ready and completed_id != &"":
		shift.apply_completed_event(completed_id, 1)
	if _mode != SHIFT_COMPLETE:
		_set_mode(EXPLORATION)


func _on_shift_finished() -> void:
	_summary_panel.render(shift, journal, service)
	_set_mode(SHIFT_COMPLETE)


func _on_term_added(_term_id: StringName) -> void:
	if _mode == JOURNAL:
		_journal_panel.render(journal, _journal_return == DIALOGUE, _journal_return == SHIFT_COMPLETE, _journal_return == HOME)
	elif _mode == DIALOGUE:
		_dialogue_panel.render(runner, journal)
	journal_changed.emit(journal.get_known_term_ids().size())


func _set_mode(value: StringName) -> void:
	_mode = value
	_sync_panels()
	mode_changed.emit(_mode)


func _sync_panels() -> void:
	_dialogue_panel.set_open(_mode == DIALOGUE)
	_journal_panel.set_open(_mode == JOURNAL)
	if _service_ready:
		_service_panel.set_open(_mode == SERVICE)
	if _shift_ready:
		_summary_panel.set_open(_mode == SHIFT_COMPLETE)
	if _commute_panel != null:
		var home_journal := _mode == JOURNAL and _journal_return == HOME
		_commute_panel.set_open(_mode in [TRAVEL, HOME] or home_journal, _mode == TRAVEL, not home_journal)
