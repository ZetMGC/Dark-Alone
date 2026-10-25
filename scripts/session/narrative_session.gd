class_name NarrativeSession
extends Node
## Владеет моделями и порядком модальных экранов. Камеру связывает Main.

signal mode_changed(mode: StringName)
signal journal_changed(count: int)

const EXPLORATION := &"exploration"
const DIALOGUE := &"dialogue"
const JOURNAL := &"journal"
const MENU := &"menu"

var mode: StringName:
	get: return _mode
var runner := DialogueRunner.new()
var journal := Journal.new()

var _mode: StringName = EXPLORATION
var _journal_return: StringName = EXPLORATION
var _menu_return: StringName = EXPLORATION
var _dialogue_panel: DialoguePanel
var _journal_panel: JournalPanel
var _configured: bool = false
var _changing: bool = false


func configure(catalog: DialogueCatalog, dialogue_panel: DialoguePanel, journal_panel: JournalPanel) -> bool:
	if _configured or dialogue_panel == null or journal_panel == null:
		return false
	if not journal.configure(catalog) or not runner.configure(catalog, journal):
		return false
	_dialogue_panel = dialogue_panel
	_journal_panel = journal_panel
	_dialogue_panel.choice_requested.connect(choose_for_node)
	_dialogue_panel.finish_requested.connect(finish_for_node)
	_dialogue_panel.cancel_requested.connect(cancel_dialogue)
	_dialogue_panel.journal_requested.connect(open_journal)
	_journal_panel.close_requested.connect(close_journal)
	runner.node_changed.connect(_on_node_changed)
	runner.dialogue_finished.connect(_on_dialogue_closed)
	runner.dialogue_cancelled.connect(_on_dialogue_closed)
	journal.term_added.connect(_on_term_added)
	_configured = true
	_sync_panels()
	return true


func start_dialogue(dialogue_id: StringName) -> bool:
	if not _configured or _changing or _mode != EXPLORATION:
		return false
	_changing = true
	var accepted := runner.start(dialogue_id)
	if accepted:
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
	if not _configured or _changing or _mode not in [EXPLORATION, DIALOGUE]:
		return false
	_changing = true
	_journal_return = _mode
	_journal_panel.render(journal, _journal_return == DIALOGUE)
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
	_set_mode(EXPLORATION)


func _on_term_added(_term_id: StringName) -> void:
	if _mode == JOURNAL:
		_journal_panel.render(journal, _journal_return == DIALOGUE)
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
