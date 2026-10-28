class_name DialogueContentValidator
extends RefCounted
## Проверяет структуру и ссылки без исполнения диалога или изменения прогресса.

var _errors: PackedStringArray = []
var _id_pattern := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
var _conclusion_ids: Dictionary = {}


func validate(glossary: Variant, documents: Array, glossary_source: String = "glossary", sources: PackedStringArray = []) -> PackedStringArray:
	_errors = []
	_conclusion_ids = {}
	var terms := _validate_glossary(glossary, glossary_source)
	if glossary is Dictionary:
		var groups: Variant = glossary.get("reasoning_groups", [])
		if not JournalReasoning.validate_groups(groups, PackedStringArray(terms.keys())):
			_error(glossary_source + ".reasoning_groups", "invalid groups, terms, positions or conclusion options")
		else:
			for group in groups:
				for option in group.options:
					_conclusion_ids[option.id] = true
			if not JournalReasoning.validate_links(glossary.get("reasoning_links", []), groups):
				_error(glossary_source + ".reasoning_links", "invalid group link, sheet or conclusion condition")
		_validate_recipes(glossary.get("journal_recipes", []), terms, glossary_source)
	var dialogue_ids: Dictionary = {}
	if documents.is_empty():
		_error("dialogues", "at least one document is required")
	for index in documents.size():
		var source := sources[index] if index < sources.size() else "documents[%d]" % index
		var document: Variant = documents[index]
		if not _document(document, "dialogues", source):
			continue
		if document.dialogues.is_empty():
			_error(source + ".dialogues", "must not be empty")
		for item_index in document.dialogues.size():
			var path := source + ".dialogues[%d]" % item_index
			var item: Variant = document.dialogues[item_index]
			if not item is Dictionary:
				_error(path, "expected object")
				continue
			_fields(item, ["id", "title", "start_node", "nodes"], ["allow_cycles", "cycle_note"], path)
			_register_id(item.get("id"), dialogue_ids, path + ".id")
			_text(item.get("title"), path + ".title")
			_validate_dialogue(item, terms, path)
	return _errors.duplicate()


func _validate_recipes(data: Variant, terms: Dictionary, path: String) -> void:
	if not data is Array or data.size() > 32:
		_error(path + ".journal_recipes", "expected at most 32 authored recipes")
		return
	var ids: Dictionary = {}
	for index in data.size():
		var item: Variant = data[index]
		var location := path + ".journal_recipes[%d]" % index
		if not item is Dictionary:
			_error(location, "expected recipe object")
			continue
		_fields(item, ["id", "title", "text", "required_terms"], [], location)
		_register_id(item.get("id"), ids, location + ".id")
		_text(item.get("title"), location + ".title")
		_text(item.get("text"), location + ".text")
		if item.get("text") is String and item.text.length() > 4000:
			_error(location, "recipe too long")
		_term_list(item.get("required_terms"), terms, location + ".required_terms")


func _validate_glossary(document: Variant, path: String) -> Dictionary:
	var terms: Dictionary = {}
	if not _document(document, "terms", path):
		return terms
	for index in document.terms.size():
		var item_path := path + ".terms[%d]" % index
		var item: Variant = document.terms[index]
		if not item is Dictionary:
			_error(item_path, "expected object")
			continue
		_fields(item, ["id", "title", "description"], [], item_path)
		_register_id(item.get("id"), terms, item_path + ".id")
		_text(item.get("title"), item_path + ".title")
		_text(item.get("description"), item_path + ".description")
	return terms


func _document(value: Variant, collection: String, path: String) -> bool:
	if not value is Dictionary:
		_error(path, "expected document object")
		return false
	_fields(value, ["schema_version", "test_content", collection], ["reasoning_groups", "reasoning_links", "journal_recipes"] if collection == "terms" else [], path)
	var version: Variant = value.get("schema_version")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or version != 1:
		_error(path + ".schema_version", "supported version is 1")
	if not value.get("test_content") is bool:
		_error(path + ".test_content", "expected boolean")
	if not value.get(collection) is Array:
		_error(path + "." + collection, "expected array")
		return false
	return true


func _validate_dialogue(dialogue: Dictionary, terms: Dictionary, path: String) -> void:
	var start: Variant = dialogue.get("start_node")
	_id(start, path + ".start_node")
	var allow_cycles: Variant = dialogue.get("allow_cycles", false)
	if not allow_cycles is bool:
		_error(path + ".allow_cycles", "expected boolean")
	if dialogue.has("cycle_note"):
		_text(dialogue.cycle_note, path + ".cycle_note")
	if allow_cycles is bool and allow_cycles:
		_text(dialogue.get("cycle_note"), path + ".cycle_note")
	if not dialogue.get("nodes") is Array:
		_error(path + ".nodes", "expected array")
		return
	var nodes: Dictionary = {}
	var effects: Dictionary = {}
	for index in dialogue.nodes.size():
		var node_path := path + ".nodes[%d]" % index
		var node: Variant = dialogue.nodes[index]
		if not node is Dictionary:
			_error(node_path, "expected object")
			continue
		if _register_id(node.get("id"), nodes, node_path + ".id"):
			nodes[node.id] = node
		_validate_node(node, terms, effects, node_path)
	if not start is String or not nodes.has(start):
		_error(path + ".start_node", "missing start node")
		return
	_validate_graph(nodes, start, allow_cycles is bool and allow_cycles, path)


func _validate_node(node: Dictionary, terms: Dictionary, effects: Dictionary, path: String) -> void:
	_fields(node, ["id", "speaker", "text", "end", "choices"], ["effects"], path)
	_text(node.get("speaker"), path + ".speaker")
	_text(node.get("text"), path + ".text")
	var terminal: Variant = node.get("end")
	if not terminal is bool:
		_error(path + ".end", "expected boolean")
	var choices: Variant = node.get("choices")
	if not choices is Array:
		_error(path + ".choices", "expected array")
	else:
		if terminal is bool and terminal == not choices.is_empty():
			_error(path + ".choices", "end nodes require no choices; other nodes require choices")
		var choice_ids: Dictionary = {}
		for index in choices.size():
			var choice_path := path + ".choices[%d]" % index
			var choice: Variant = choices[index]
			if not choice is Dictionary:
				_error(choice_path, "expected object")
				continue
			_fields(choice, ["id", "text", "target"], ["required_terms", "required_conclusions"], choice_path)
			_register_id(choice.get("id"), choice_ids, choice_path + ".id")
			_text(choice.get("text"), choice_path + ".text")
			_id(choice.get("target"), choice_path + ".target")
			_term_list(choice.get("required_terms", []), terms, choice_path + ".required_terms")
			_term_list(choice.get("required_conclusions", []), _conclusion_ids, choice_path + ".required_conclusions")
	var node_effects: Variant = node.get("effects", [])
	if not node_effects is Array:
		_error(path + ".effects", "expected array")
		return
	for index in node_effects.size():
		var effect_path := path + ".effects[%d]" % index
		var effect: Variant = node_effects[index]
		if not effect is Dictionary:
			_error(effect_path, "expected object")
			continue
		_fields(effect, ["effect_id", "type", "term_id"], [], effect_path)
		_register_id(effect.get("effect_id"), effects, effect_path + ".effect_id")
		if effect.get("type") != "grant_term":
			_error(effect_path + ".type", "supported effect is grant_term")
		_term_reference(effect.get("term_id"), terms, effect_path + ".term_id")


func _validate_graph(nodes: Dictionary, start: String, allow_cycles: bool, path: String) -> void:
	var edges: Dictionary = {}
	var reverse: Dictionary = {}
	var degree: Dictionary = {}
	var endings: Array = []
	for id: String in nodes:
		edges[id] = []
		reverse[id] = []
		degree[id] = 0
		if nodes[id].get("end") is bool and nodes[id].end:
			endings.append(id)
	for id: String in nodes:
		var choices: Variant = nodes[id].get("choices", [])
		if not choices is Array:
			continue
		for choice: Variant in choices:
			if not choice is Dictionary or not choice.get("target") is String:
				continue
			var target: String = choice.target
			if not nodes.has(target):
				_error(path + ".node[" + id + "]", "missing target node '" + target + "'")
				continue
			edges[id].append(target)
			reverse[target].append(id)
			degree[target] += 1
	var reachable := _walk([start], edges)
	var can_end := _walk(endings, reverse)
	for id: String in nodes:
		if not reachable.has(id):
			_error(path + ".node[" + id + "]", "unreachable node")
		if not can_end.has(id):
			_error(path + ".node[" + id + "]", "no path to an end node")
	var ready: Array = []
	for id: String in degree:
		if degree[id] == 0:
			ready.append(id)
	var visited := 0
	while not ready.is_empty():
		var id: String = ready.pop_back()
		visited += 1
		for target: String in edges[id]:
			degree[target] -= 1
			if degree[target] == 0:
				ready.append(target)
	if visited != nodes.size() and not allow_cycles:
		_error(path, "cycle requires allow_cycles=true and cycle_note")


func _walk(starts: Array, edges: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var pending := starts.duplicate()
	while not pending.is_empty():
		var id: String = pending.pop_back()
		if seen.has(id):
			continue
		seen[id] = true
		pending.append_array(edges[id])
	return seen


func _fields(value: Dictionary, required: Array, optional: Array, path: String) -> void:
	for key: String in required:
		if not value.has(key):
			_error(path + "." + key, "required field is missing")
	for key: Variant in value:
		if key not in required and key not in optional:
			_error(path, "unknown field '" + str(key) + "'")


func _text(value: Variant, path: String) -> bool:
	if not value is String or value.strip_edges().is_empty():
		_error(path, "expected non-empty string")
		return false
	return true


func _id(value: Variant, path: String) -> bool:
	if not value is String or _id_pattern.search(value) == null:
		_error(path, "expected snake_case id beginning with a letter")
		return false
	return true


func _register_id(value: Variant, seen: Dictionary, path: String) -> bool:
	if not _id(value, path):
		return false
	if seen.has(value):
		_error(path, "duplicate id '" + str(value) + "'")
		return false
	seen[value] = true
	return true


func _term_reference(value: Variant, terms: Dictionary, path: String) -> void:
	if _id(value, path) and not terms.has(value):
		_error(path, "unknown term id '" + str(value) + "'")


func _term_list(value: Variant, terms: Dictionary, path: String) -> void:
	if not value is Array:
		_error(path, "expected array")
		return
	var seen: Dictionary = {}
	for index in value.size():
		var item_path := path + "[%d]" % index
		if _register_id(value[index], seen, item_path):
			_term_reference(value[index], terms, item_path)


func _error(path: String, message: String) -> void:
	_errors.append(path + ": " + message)
