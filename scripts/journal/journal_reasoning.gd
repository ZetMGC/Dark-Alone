class_name JournalReasoning
extends RefCounted
## Авторские группы сведений и выводы игрока. Правильность определяет сценарий, не интерфейс.

signal changed
var _groups: Array = []
var _records: Array = []


static func validate_groups(data: Variant, terms: PackedStringArray) -> bool:
	if not data is Array or data.size() > 32:
		return false
	var ids: Dictionary = {}
	var options: Dictionary = {}
	var per_sheet: Dictionary = {}
	for group in data:
		if not group is Dictionary or group.size() != 7 or not valid_id(group.get("id")) or ids.has(group.id) or not group.get("title") is String or group.title.strip_edges().is_empty() or group.title.length() > 100:
			return false
		if not group.get("terms") is Array or group.terms.size() < 2 or group.terms.size() > 8 or not group.get("position") is Array or group.position.size() != 2 or not group.get("options") is Array or group.options.size() < 2 or group.options.size() > 4:
			return false
		var minimum := integer(group.get("minimum_terms"))
		var sheet := integer(group.get("sheet"))
		if minimum < 2 or minimum > group.terms.size() or sheet < 0 or sheet >= 8:
			return false
		for coordinate in group.position:
			if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or coordinate < 0.12 or coordinate > 0.85:
				return false
		var seen: Dictionary = {}
		for id in group.terms:
			if not id is String or id not in terms or seen.has(id):
				return false
			seen[id] = true
		for option in group.options:
			if not option is Dictionary or option.size() != 2 or not valid_id(option.get("id")) or options.has(option.id) or not option.get("text") is String or option.text.strip_edges().is_empty() or option.text.length() > 240:
				return false
			options[option.id] = true
		ids[group.id] = true
		per_sheet[sheet] = int(per_sheet.get(sheet, 0)) + 1
		if per_sheet[sheet] > 4:
			return false
	return true


static func valid_id(value: Variant) -> bool:
	return value is String and value.length() <= 80 and RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(value) != null


static func integer(value: Variant) -> int:
	return int(value) if (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= 1000000000 and value == floorf(float(value)) else -1


func configure(groups: Array) -> void:
	_groups = groups.duplicate(true)


func get_definitions() -> Array:
	return _groups.duplicate(true)


func get_groups(known: PackedStringArray, sheet: int) -> Array:
	var result: Array = []
	for group in _groups:
		if group.sheet != sheet:
			continue
		var evidence: Array = []
		for id in group.terms:
			if id in known:
				evidence.append(id)
		if evidence.is_empty():
			continue
		var view: Dictionary = group.duplicate(true)
		view.terms = evidence
		view.ready = evidence.size() >= group.minimum_terms
		# Варианты не раскрываются до накопления достаточных сведений.
		if not view.ready:
			view.options = []
		view.conclusion = get_record(StringName(group.id))
		result.append(view)
	return result


func get_record(group_id: StringName) -> Dictionary:
	for record in _records:
		if record.group_id == str(group_id):
			return record.duplicate(true)
	return {}


func has_conclusion(option_id: StringName) -> bool:
	for record in _records:
		if record.option_id == str(option_id):
			return true
	return false


func choose(group_id: StringName, option_id: StringName, known: PackedStringArray) -> bool:
	if not get_record(group_id).is_empty():
		return false
	for group in _groups:
		if group.id != str(group_id):
			continue
		var evidence: Array = []
		for id in group.terms:
			if id in known:
				evidence.append(id)
		if evidence.size() < group.minimum_terms:
			return false
		for option in group.options:
			if option.id == str(option_id):
				_records.append({"group_id": str(group_id), "option_id": str(option_id), "evidence": evidence})
				changed.emit()
				return true
	return false


func export_data() -> Array:
	return _records.duplicate(true)


func restore_data(data: Variant, known: PackedStringArray) -> bool:
	if not data is Array or data.size() > _groups.size():
		return false
	var staged := JournalReasoning.new()
	staged.configure(_groups)
	for record in data:
		if not record is Dictionary or record.size() != 3 or not record.get("group_id") is String or not record.get("option_id") is String or not record.get("evidence") is Array:
			return false
		var evidence := PackedStringArray()
		for id in record.evidence:
			if not id is String or id not in known or id in evidence:
				return false
			evidence.append(id)
		if not staged.choose(StringName(record.group_id), StringName(record.option_id), evidence):
			return false
		# choose игнорирует посторонние слова: в сохранении это ошибка, а не лишний факт.
		if staged._records.back().evidence.size() != evidence.size():
			return false
	_records = staged._records
	return true
