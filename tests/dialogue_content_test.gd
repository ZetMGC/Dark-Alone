extends SceneTree
## Контент, граф, ошибки файлов и атомарность каталога; никакого игрового UI.

const GLOSSARY := "res://content/glossary/test_terms.json"
const DIALOGUE := "res://content/dialogues/test_guest.json"

var _checks: int = 0
var _failures: int = 0
var _glossary: Dictionary
var _document: Dictionary


func _initialize() -> void:
	_glossary = JSON.parse_string(FileAccess.get_file_as_string(GLOSSARY))
	_document = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE))
	_test_valid_and_copies()
	_test_invalid_structure()
	_test_references_and_graph()
	_test_files_and_atomic_reload()
	print("%s: dialogue content, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _reject(glossary: Variant, documents: Array, diagnostic: String) -> void:
	var catalog := DialogueCatalog.new()
	_expect(not catalog.load_data(glossary, documents), "Reject invalid bundle: " + diagnostic)
	_expect("; ".join(catalog.validation_errors).contains(diagnostic), "Specific diagnostic: " + diagnostic)
	_expect(not catalog.is_loaded() and catalog.get_dialogue_ids().is_empty() and catalog.get_term_ids().is_empty(),
		"Failed initial load exposes no partial content")


func _test_valid_and_copies() -> void:
	var catalog := DialogueCatalog.new()
	_expect(catalog.load_files(GLOSSARY, PackedStringArray([DIALOGUE])), "Shipped JSON files load")
	_expect(catalog.validation_errors.is_empty() and catalog.is_loaded(), "Successful state")
	_expect(catalog.get_term_ids() == PackedStringArray(["test_marker", "test_signal"]), "Term IDs sorted")
	_expect(catalog.get_dialogue_ids() == PackedStringArray(["test_guest_intro"]), "Dialogue IDs indexed")
	_expect(catalog.has_term(&"test_signal") and catalog.has_dialogue(&"test_guest_intro"), "Known IDs resolve")
	_expect(not catalog.has_term(&"missing") and not catalog.has_dialogue(&"missing"), "Unknown IDs absent")
	_expect(catalog.get_node(&"missing", &"opening").is_empty(), "Missing dialogue returns empty node")
	_expect(catalog.get_node(&"test_guest_intro", &"missing").is_empty(), "Missing node returns empty dictionary")
	_expect(catalog.get_term(&"missing").is_empty(), "Missing term returns empty dictionary")
	_expect(catalog.get_dialogue(&"test_guest_intro").test_content, "Test marker carried into dialogue snapshot")
	_expect(catalog.get_term(&"test_signal").test_content, "Test marker carried into term snapshot")
	var node := catalog.get_node(&"test_guest_intro", &"opening")
	_expect(node.choices[0].id == "ask_more" and node.choices[1].id == "leave", "Choice order preserved")
	node.choices[0].text = "CHANGED"
	_expect(catalog.get_node(&"test_guest_intro", &"opening").choices[0].text != "CHANGED", "Node getter is a deep copy")
	var dialogue := catalog.get_dialogue(&"test_guest_intro")
	dialogue.nodes.clear()
	_expect(catalog.get_dialogue(&"test_guest_intro").nodes.size() == 3, "Dialogue getter is a deep copy")
	var term := catalog.get_term(&"test_signal")
	term.description = "CHANGED"
	_expect(catalog.get_term(&"test_signal").description != "CHANGED", "Term getter is a copy")
	var source := _document.duplicate(true)
	_expect(catalog.load_data(_glossary, [source]), "In-memory data loads")
	source.dialogues[0].nodes[0].text = "CHANGED"
	_expect(catalog.get_node(&"test_guest_intro", &"opening").text != "CHANGED", "Source mutation cannot change accepted snapshot")


func _test_invalid_structure() -> void:
	_reject(null, [_document], "expected document object")
	_reject(_glossary, [null], "expected document object")
	_reject(_glossary, [], "at least one document")
	for version: Variant in [0, 2, "1", true]:
		var data := _document.duplicate(true)
		data.schema_version = version
		_reject(_glossary, [data], "supported version is 1")
	var data := _document.duplicate(true)
	data.test_content = "true"
	_reject(_glossary, [data], "expected boolean")
	data = _document.duplicate(true)
	data.dialogues = "wrong"
	_reject(_glossary, [data], "expected array")
	data = _document.duplicate(true)
	data.dialogues.clear()
	_reject(_glossary, [data], "must not be empty")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0].erase("text")
	_reject(_glossary, [data], "required field is missing")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0]["choises"] = []
	_reject(_glossary, [data], "unknown field 'choises'")
	data = _document.duplicate(true)
	data.dialogues[0].id = "Bad Id"
	_reject(_glossary, [data], "expected snake_case")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0].text = "  "
	_reject(_glossary, [data], "expected non-empty string")
	for field: String in ["nodes", "choices", "effects", "required_terms"]:
		data = _document.duplicate(true)
		match field:
			"nodes": data.dialogues[0].nodes = false
			"choices": data.dialogues[0].nodes[0].choices = false
			"effects": data.dialogues[0].nodes[0].effects = false
			"required_terms": data.dialogues[0].nodes[0].choices[0].required_terms = false
		_reject(_glossary, [data], "expected array")
	for container: String in ["dialogue", "node", "choice", "effect"]:
		data = _document.duplicate(true)
		match container:
			"dialogue": data.dialogues[0] = null
			"node": data.dialogues[0].nodes[0] = null
			"choice": data.dialogues[0].nodes[0].choices[0] = null
			"effect": data.dialogues[0].nodes[0].effects[0] = null
		_reject(_glossary, [data], "expected object")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0].end = true
	_reject(_glossary, [data], "end nodes require no choices")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0].choices.clear()
	_reject(_glossary, [data], "other nodes require choices")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0].end = "false"
	_reject(_glossary, [data], "expected boolean")


func _test_references_and_graph() -> void:
	var glossary := _glossary.duplicate(true)
	glossary.terms.append(glossary.terms[0].duplicate(true))
	_reject(glossary, [_document], "duplicate id")
	var data := _document.duplicate(true)
	data.dialogues.append(data.dialogues[0].duplicate(true))
	_reject(_glossary, [data], "duplicate id")
	_reject(_glossary, [_document, _document.duplicate(true)], "duplicate id")
	data = _document.duplicate(true)
	data.dialogues[0].nodes.append(data.dialogues[0].nodes[0].duplicate(true))
	_reject(_glossary, [data], "duplicate id")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0].choices[1].id = "ask_more"
	_reject(_glossary, [data], "duplicate id")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[1].effects[0].effect_id = "learn_first_term"
	_reject(_glossary, [data], "duplicate id")
	data = _document.duplicate(true)
	data.dialogues[0].start_node = "missing"
	_reject(_glossary, [data], "missing start node")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0].choices[0].target = "missing"
	_reject(_glossary, [data], "missing target node")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0].effects[0].term_id = "missing"
	_reject(_glossary, [data], "unknown term id")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0].choices[0].required_terms = ["missing"]
	_reject(_glossary, [data], "unknown term id")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0].choices[0].required_terms = ["test_signal", "test_signal"]
	_reject(_glossary, [data], "duplicate id")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[0].effects[0].type = "spend_time"
	_reject(_glossary, [data], "supported effect is grant_term")
	data = _document.duplicate(true)
	var unreachable: Dictionary = data.dialogues[0].nodes[2].duplicate(true)
	unreachable.id = "unreachable"
	data.dialogues[0].nodes.append(unreachable)
	_reject(_glossary, [data], "unreachable node")
	data = _document.duplicate(true)
	data.dialogues[0].nodes[1].choices[0].target = "opening"
	_reject(_glossary, [data], "cycle requires")
	data.dialogues[0].allow_cycles = true
	_reject(_glossary, [data], "cycle_note")
	data.dialogues[0].cycle_note = "[TEST] Намеренный возврат к началу; выход через leave."
	var catalog := DialogueCatalog.new()
	_expect(catalog.load_data(_glossary, [data]), "Documented cycle with exit is valid")
	data.dialogues[0].nodes.remove_at(2)
	data.dialogues[0].nodes[0].choices[1].target = "explanation"
	_reject(_glossary, [data], "no path to an end node")


func _test_files_and_atomic_reload() -> void:
	var catalog := DialogueCatalog.new()
	_expect(not catalog.load_files("res://content/missing.json", PackedStringArray([DIALOGUE])), "Missing glossary rejected")
	_expect(not catalog.is_loaded() and not catalog.validation_errors.is_empty(), "File errors leave empty catalog")
	_expect(catalog.load_files(GLOSSARY, PackedStringArray([DIALOGUE])), "Initial snapshot accepted")
	var before := catalog.get_dialogue(&"test_guest_intro")
	_expect(not catalog.load_files(GLOSSARY, PackedStringArray([DIALOGUE, "res://content/missing.json"])), "Missing second pack rejects reload")
	_expect(catalog.get_dialogue(&"test_guest_intro") == before and catalog.is_loaded(), "File failure preserves old snapshot")
	var invalid := _document.duplicate(true)
	invalid.dialogues[0].nodes[0].choices[0].target = "missing"
	_expect(not catalog.load_data(_glossary, [invalid]), "Invalid reload rejected")
	_expect(catalog.get_dialogue(&"test_guest_intro") == before, "Validation failure preserves old snapshot")
	var path := "user://dialogue_content_test_%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "Can create temporary malformed JSON")
		return
	file.store_string("{ invalid JSON")
	file.close()
	_expect(not catalog.load_files(GLOSSARY, PackedStringArray([path])), "Malformed JSON rejected")
	_expect("; ".join(catalog.validation_errors).contains(path) and "; ".join(catalog.validation_errors).contains("invalid JSON"),
		"Syntax error identifies file and diagnostic")
	_expect(catalog.get_dialogue(&"test_guest_intro") == before, "Syntax failure preserves snapshot")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var replacement := _document.duplicate(true)
	replacement.dialogues[0].id = "replacement"
	_expect(catalog.load_data(_glossary, [replacement]), "Valid reload accepted")
	_expect(catalog.validation_errors.is_empty() and catalog.has_dialogue(&"replacement") and not catalog.has_dialogue(&"test_guest_intro"),
		"Successful reload replaces complete index and clears errors")
