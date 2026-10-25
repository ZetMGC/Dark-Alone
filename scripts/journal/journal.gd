class_name Journal
extends RefCounted
## Прогресс текущей сессии; определения отделены от набора известных слов.

signal term_added(term_id: StringName)

var _definitions: Dictionary = {}
var _known: Dictionary = {}
var _order: PackedStringArray = []
var _configured: bool = false


func configure(catalog: DialogueCatalog) -> bool:
	if _configured or catalog == null or not catalog.is_loaded():
		return false
	for id in catalog.get_term_ids():
		_definitions[id] = catalog.get_term(StringName(id))
	_configured = true
	return true


func is_configured() -> bool:
	return _configured


func add_term(term_id: StringName) -> bool:
	var id := str(term_id)
	if not _definitions.has(id) or _known.has(id):
		return false
	_known[id] = true
	_order.append(id)
	term_added.emit(term_id)
	return true


func has_term(term_id: StringName) -> bool:
	return _known.has(str(term_id))


func get_definition(term_id: StringName) -> Dictionary:
	return _definitions.get(str(term_id), {}).duplicate(true)


func get_known_term_ids() -> PackedStringArray:
	return _order.duplicate()


func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id in _order:
		entries.append(get_definition(StringName(id)))
	return entries
