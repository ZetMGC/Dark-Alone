class_name DialogueCatalog
extends RefCounted
## Атомарный каталог принятого контента. Не хранит игровой прогресс.

var validation_errors: PackedStringArray = []

var _terms: Dictionary = {}
var _dialogues: Dictionary = {}
var _nodes: Dictionary = {}
var _loaded: bool = false
var _reasoning_groups: Array = []
var _reasoning_links: Array = []
var _journal_recipes: Array = []


func load_files(glossary_path: String, dialogue_paths: PackedStringArray) -> bool:
	var file_errors: PackedStringArray = []
	var glossary: Variant = _read_json(glossary_path, file_errors)
	var documents: Array = []
	for path in dialogue_paths:
		documents.append(_read_json(path, file_errors))
	if not file_errors.is_empty():
		validation_errors = file_errors
		return false
	return load_data(glossary, documents, glossary_path, dialogue_paths)


func load_data(glossary: Variant, documents: Array, glossary_source: String = "glossary", sources: PackedStringArray = []) -> bool:
	validation_errors = DialogueContentValidator.new().validate(glossary, documents, glossary_source, sources)
	if not validation_errors.is_empty():
		return false
	var new_terms: Dictionary = {}
	var new_dialogues: Dictionary = {}
	var new_nodes: Dictionary = {}
	for term: Dictionary in glossary.terms:
		var snapshot := term.duplicate(true)
		snapshot["test_content"] = glossary.test_content
		new_terms[term.id] = snapshot
	for document: Dictionary in documents:
		for dialogue: Dictionary in document.dialogues:
			var snapshot := dialogue.duplicate(true)
			snapshot["test_content"] = document.test_content
			new_dialogues[dialogue.id] = snapshot
			var node_index: Dictionary = {}
			for node: Dictionary in snapshot.nodes:
				node_index[node.id] = node
			new_nodes[dialogue.id] = node_index
	_terms = new_terms
	_reasoning_groups = glossary.get("reasoning_groups", []).duplicate(true)
	_reasoning_links = glossary.get("reasoning_links", []).duplicate(true)
	_journal_recipes = glossary.get("journal_recipes", []).duplicate(true)
	_dialogues = new_dialogues
	_nodes = new_nodes
	_loaded = true
	return true


func is_loaded() -> bool:
	return _loaded


func get_reasoning_groups() -> Array:
	return _reasoning_groups.duplicate(true)


func get_reasoning_links() -> Array:
	return _reasoning_links.duplicate(true)


func get_journal_recipes() -> Array:
	return _journal_recipes.duplicate(true)


func has_term(term_id: StringName) -> bool:
	return _terms.has(str(term_id))


func has_dialogue(dialogue_id: StringName) -> bool:
	return _dialogues.has(str(dialogue_id))


func get_term(term_id: StringName) -> Dictionary:
	return _terms.get(str(term_id), {}).duplicate(true)


func get_dialogue(dialogue_id: StringName) -> Dictionary:
	return _dialogues.get(str(dialogue_id), {}).duplicate(true)


func get_node(dialogue_id: StringName, node_id: StringName) -> Dictionary:
	return _nodes.get(str(dialogue_id), {}).get(str(node_id), {}).duplicate(true)


func get_term_ids() -> PackedStringArray:
	var ids := PackedStringArray(_terms.keys())
	ids.sort()
	return ids


func get_dialogue_ids() -> PackedStringArray:
	var ids := PackedStringArray(_dialogues.keys())
	ids.sort()
	return ids


func _read_json(path: String, errors: PackedStringArray) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append(path + ": cannot read file (error %d)" % FileAccess.get_open_error())
		return null
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		errors.append("%s:%d: invalid JSON: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return null
	return parser.data
