class_name Journal
extends RefCounted
## Прогресс текущей сессии; определения отделены от набора известных слов.

signal term_added(term_id: StringName)
signal entry_changed(term_id: StringName)
signal selection_changed(term_id: StringName)
signal reading_position_changed(term_id: StringName)
signal annotations_changed(term_id: StringName)

var selected_term_id: StringName:
	get: return _selected

var _definitions: Dictionary = {}
var _known: Dictionary = {}
var _order: PackedStringArray = []
var _configured: bool = false
var _selected: StringName = &""
var _mutating: bool = false
var _annotations: Dictionary = {}
var _ink_undo: Dictionary = {}
var _ink_redo: Dictionary = {}
var notebook := JournalNotebook.new()
const MAX_ANNOTATIONS := 64
const MAX_INK_HISTORY := 32


func get_annotations(term_id: StringName) -> Array:
	return _annotations.get(str(term_id), []).duplicate(true)


func add_annotation(term_id: StringName, kind: StringName, start: int, end: int) -> bool:
	var id := str(term_id)
	if _mutating or not has_term(term_id) or kind not in [&"underline", &"circle"] or start < 0 or end <= start or end > str(_definitions[id].description).length():
		return false
	var marks := get_annotations(term_id)
	var mark := {"kind": str(kind), "start": start, "end": end}
	if marks.size() >= MAX_ANNOTATIONS or mark in marks:
		return false
	_mutating = true
	_remember_ink(id)
	marks.append(mark)
	_annotations[id] = marks
	annotations_changed.emit(term_id)
	_mutating = false
	return true


func erase_annotation(term_id: StringName, index: int) -> bool:
	var marks := get_annotations(term_id)
	if _mutating or index < 0 or index >= marks.size():
		return false
	_mutating = true
	_remember_ink(str(term_id))
	marks.remove_at(index)
	_annotations[str(term_id)] = marks
	annotations_changed.emit(term_id)
	_mutating = false
	return true


func can_undo_annotations(term_id: StringName) -> bool:
	return not _ink_undo.get(str(term_id), []).is_empty()


func can_redo_annotations(term_id: StringName) -> bool:
	return not _ink_redo.get(str(term_id), []).is_empty()


func undo_annotations(term_id: StringName, redo: bool = false) -> bool:
	var id := str(term_id)
	var source: Dictionary = _ink_redo if redo else _ink_undo
	var destination: Dictionary = _ink_undo if redo else _ink_redo
	if _mutating or not has_term(term_id) or source.get(id, []).is_empty():
		return false
	_mutating = true
	if not destination.has(id):
		destination[id] = []
	destination[id].append(get_annotations(term_id))
	_annotations[id] = source[id].pop_back()
	annotations_changed.emit(term_id)
	_mutating = false
	return true


func _remember_ink(id: String) -> void:
	if not _ink_undo.has(id):
		_ink_undo[id] = []
	_ink_undo[id].append(_annotations.get(id, []).duplicate(true))
	if _ink_undo[id].size() > MAX_INK_HISTORY:
		_ink_undo[id].pop_front()
	_ink_redo.erase(id)


func _restore_ink(data: Variant, known: Dictionary) -> Dictionary:
	if not data is Dictionary or data.size() > known.size():
		return {"valid": false}
	var result: Dictionary = {}
	for id in data:
		if not id is String or not known.has(id) or not data[id] is Array or data[id].size() > MAX_ANNOTATIONS:
			return {"valid": false}
		var marks: Array = []
		for value in data[id]:
			if not value is Dictionary or value.size() != 3 or value.get("kind") not in ["underline", "circle"]:
				return {"valid": false}
			var start := _checkpoint_integer(value.get("start"))
			var end := _checkpoint_integer(value.get("end"))
			if start < 0 or end <= start or end > str(_definitions[id].description).length():
				return {"valid": false}
			var mark := {"kind": value.kind, "start": start, "end": end}
			if mark in marks:
				return {"valid": false}
			marks.append(mark)
		result[id] = marks
	return {"valid": true, "marks": result}


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
	_known[id] = {"entry_id": "term:" + id, "learned_order": _order.size() + 1, "source": source.duplicate(true), "read": false, "bookmarked": false, "reading_offset": 0}
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


func set_reading_offset(term_id: StringName, offset: int) -> bool:
	if _mutating or not has_term(term_id) or offset < 0 or offset > str(_definitions[str(term_id)].description).length():
		return false
	if _known[str(term_id)].reading_offset == offset:
		return false
	_mutating = true
	_known[str(term_id)].reading_offset = offset
	reading_position_changed.emit(term_id)
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


func export_progress() -> Dictionary:
	var entries: Array[Dictionary] = []
	for id in _order:
		var item: Dictionary = _known[id].duplicate(true)
		item.erase("entry_id")
		item.erase("learned_order")
		item["id"] = id
		entries.append(item)
	var progress := {"entries": entries, "selected": str(_selected)}
	var marks: Dictionary = {}
	for id in _annotations:
		if not _annotations[id].is_empty():
			marks[id] = _annotations[id].duplicate(true)
	if not marks.is_empty():
		progress["annotations"] = marks
	if not notebook.is_empty():
		progress["notebook"] = notebook.export_data()
	return progress


func restore_progress(data: Dictionary) -> bool:
	if not _configured or _mutating or not _known.is_empty() or not notebook.is_empty() or not data.get("entries") is Array or not data.get("selected") is String:
		return false
	for key in data:
		if key not in ["entries", "selected", "annotations", "notebook"]:
			return false
	var personal := JournalNotebook.new()
	if data.has("notebook") and (not data.notebook is Dictionary or not personal.restore_data(data.notebook)):
		return false
	var known: Dictionary = {}
	var order := PackedStringArray()
	for value in data.entries:
		if not value is Dictionary or value.size() != 5 or not value.get("id") is String or not value.get("source") is Dictionary or not value.get("read") is bool or not value.get("bookmarked") is bool:
			return false
		var id: String = value.id
		if not _definitions.has(id) or known.has(id):
			return false
		var offset := _checkpoint_integer(value.get("reading_offset"))
		if offset < 0 or offset > str(_definitions[id].description).length():
			return false
		var source: Dictionary = value.source.duplicate(true)
		if not source.is_empty():
			source["shift"] = _checkpoint_integer(source.get("shift"))
		if not _valid_source(source):
			return false
		order.append(id)
		known[id] = {"entry_id": "term:" + id, "learned_order": order.size(), "source": source, "read": value.read, "bookmarked": value.bookmarked, "reading_offset": offset}
	if (order.is_empty() and data.selected != "") or (not order.is_empty() and not known.has(data.selected)):
		return false
	var ink := _restore_ink(data.get("annotations", {}), known)
	if not ink.valid:
		return false
	_known = known
	_order = order
	_selected = StringName(data.selected)
	_annotations = ink.marks
	notebook = personal
	return true


static func _checkpoint_integer(value: Variant) -> int:
	if (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 1000000000 and float(value) == floorf(float(value)):
		return int(value)
	return -1
