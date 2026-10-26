class_name Journal
extends RefCounted
## Прогресс текущей сессии; определения отделены от набора известных слов.

signal term_added(term_id: StringName)
signal entry_changed(term_id: StringName)
signal selection_changed(term_id: StringName)

var selected_term_id: StringName:
	get: return _selected

var _definitions: Dictionary = {}
var _known: Dictionary = {}
var _order: PackedStringArray = []
var _configured: bool = false
var _selected: StringName = &""
var _mutating: bool = false


func configure(catalog: DialogueCatalog) -> bool:
	if _configured or catalog == null or not catalog.is_loaded():
		return false
	for id in catalog.get_term_ids():
		_definitions[id] = catalog.get_term(StringName(id))
	_configured = true
	return true


func is_configured() -> bool:
	return _configured


func matches_catalog(catalog: DialogueCatalog) -> bool:
	if not _configured or catalog == null or not catalog.is_loaded() or catalog.get_term_ids().size() != _definitions.size():
		return false
	for id in catalog.get_term_ids():
		if not _definitions.has(id) or _definitions[id] != catalog.get_term(StringName(id)):
			return false
	return true


func add_term(term_id: StringName, source: Dictionary = {}) -> bool:
	var id := str(term_id)
	if _mutating or not _definitions.has(id) or _known.has(id) or not _valid_source(source):
		return false
	_mutating = true
	_known[id] = {"entry_id": "term:" + id, "learned_order": _order.size() + 1, "source": source.duplicate(true), "read": false, "bookmarked": false}
	_order.append(id)
	if _selected == &"":
		_selected = term_id
	term_added.emit(term_id)
	_mutating = false
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
		entries.append(get_entry(StringName(id)))
	return entries


func get_entry(term_id: StringName) -> Dictionary:
	if not has_term(term_id):
		return {}
	var entry := get_definition(term_id)
	entry.merge(_known[str(term_id)].duplicate(true))
	return entry


func get_filtered_entries(query: String = "", section: StringName = &"all") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if section not in [&"all", &"new", &"bookmarks"]:
		return result
	var search := query.strip_edges().to_lower()
	for entry in get_entries():
		if section == &"new" and entry.read or section == &"bookmarks" and not entry.bookmarked:
			continue
		if search.is_empty() or (str(entry.title) + " " + str(entry.description)).to_lower().contains(search):
			result.append(entry)
	return result


func get_unread_count() -> int:
	var count: int = 0
	for entry: Dictionary in _known.values():
		if not entry.read:
			count += 1
	return count


func select_entry(term_id: StringName) -> bool:
	if _mutating or not has_term(term_id):
		return false
	_mutating = true
	var changed := _selected != term_id
	_selected = term_id
	if not _known[str(term_id)].read:
		_known[str(term_id)].read = true
		entry_changed.emit(term_id)
	if changed:
		selection_changed.emit(term_id)
	_mutating = false
	return true


func set_bookmarked(term_id: StringName, value: bool) -> bool:
	if _mutating or not has_term(term_id) or _known[str(term_id)].bookmarked == value:
		return false
	_mutating = true
	_known[str(term_id)].bookmarked = value
	entry_changed.emit(term_id)
	_mutating = false
	return true


func _valid_source(source: Dictionary) -> bool:
	if source.is_empty():
		return true
	if source.size() != 4:
		return false
	for key in ["dialogue_id", "node_id", "speaker"]:
		if not source.get(key) is String or str(source[key]).strip_edges().is_empty():
			return false
	return source.get("shift") is int and source.shift > 0
