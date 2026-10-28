class_name DialogueRunner
extends RefCounted
## Исполнитель снимка данных. Никаких зависимостей от камеры и UI.

signal node_changed(dialogue_id: StringName, node_id: StringName)
signal dialogue_finished(dialogue_id: StringName)
signal dialogue_cancelled(dialogue_id: StringName)

var active: bool:
	get: return _active
var current_dialogue_id: StringName:
	get: return _dialogue_id
var current_node_id: StringName:
	get: return _node_id

var _dialogues: Dictionary = {}
var _journal: Journal
var _configured: bool = false
var _active: bool = false
var _mutating: bool = false
var _dialogue_id: StringName = &""
var _node_id: StringName = &""
var _nodes: Dictionary = {}
var _applied: Dictionary = {}
var _shift_number: int = 1


func configure(catalog: DialogueCatalog, journal: Journal, shift_number: int = 1) -> bool:
	if _configured or catalog == null or not catalog.is_loaded() or journal == null or not journal.is_configured() or shift_number < 1:
		return false
	for id in catalog.get_term_ids():
		if journal.get_definition(StringName(id)).is_empty():
			return false
	for id in catalog.get_dialogue_ids():
		_dialogues[id] = catalog.get_dialogue(StringName(id))
	_journal = journal
	_shift_number = shift_number
	_configured = true
	return true


func start(dialogue_id: StringName) -> bool:
	if not _configured or _active or _mutating or not _dialogues.has(str(dialogue_id)):
		return false
	_mutating = true
	_dialogue_id = dialogue_id
	_nodes = {}
	var dialogue: Dictionary = _dialogues[str(dialogue_id)]
	for node: Dictionary in dialogue.nodes:
		_nodes[node.id] = node
	_active = true
	_enter_node(StringName(dialogue.start_node))
	_mutating = false
	return true


func choose(choice_id: StringName) -> bool:
	if not _active or _mutating or is_terminal():
		return false
	for choice in get_choices():
		if StringName(choice.id) == choice_id and choice.available:
			_mutating = true
			_enter_node(StringName(choice.target))
			_mutating = false
			return true
	return false


func finish() -> bool:
	if not _active or _mutating or not is_terminal():
		return false
	_mutating = true
	var id := _dialogue_id
	_clear_current()
	dialogue_finished.emit(id)
	_mutating = false
	return true


func cancel() -> bool:
	if not _active or _mutating:
		return false
	_mutating = true
	var id := _dialogue_id
	_clear_current()
	dialogue_cancelled.emit(id)
	_mutating = false
	return true


func get_current_node() -> Dictionary:
	return _nodes.get(str(_node_id), {}).duplicate(true) if _active else {}


func get_dialogue_title() -> String:
	return str(_dialogues.get(str(_dialogue_id), {}).get("title", ""))


func is_terminal() -> bool:
	return _active and _nodes[str(_node_id)].end


func get_choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _active:
		return result
	for original: Dictionary in _nodes[str(_node_id)].choices:
		var choice := original.duplicate(true)
		var missing: PackedStringArray = []
		for id: String in original.get("required_terms", []):
			if not _journal.has_term(StringName(id)):
				missing.append(id)
		choice["missing_terms"] = missing
		var missing_conclusions := PackedStringArray()
		for id: String in original.get("required_conclusions", []):
			if not _journal.has_conclusion(StringName(id)):
				missing_conclusions.append(id)
		choice["missing_conclusions"] = missing_conclusions
		choice["available"] = missing.is_empty() and missing_conclusions.is_empty()
		result.append(choice)
	return result


func _enter_node(node_id: StringName) -> void:
	_node_id = node_id
	var node: Dictionary = _nodes[str(node_id)]
	# Весь снимок уже проверен каталогом; все term_id проверены configure.
	for effect: Dictionary in node.get("effects", []):
		var key := str(_dialogue_id) + ":" + str(effect.effect_id)
		if not _applied.has(key):
			_applied[key] = true
			_journal.add_term(StringName(effect.term_id), {"dialogue_id": str(_dialogue_id), "node_id": str(_node_id), "speaker": str(node.speaker), "shift": _shift_number})
	node_changed.emit(_dialogue_id, _node_id)


func _clear_current() -> void:
	_active = false
	_dialogue_id = &""
	_node_id = &""
	_nodes = {}
