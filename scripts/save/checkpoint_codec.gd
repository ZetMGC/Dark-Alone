class_name CheckpointCodec
extends RefCounted
## Контрольная точка — только начало смены, без ссылок на дерево/текущую реплику.

const VERSION := 1
var last_error: String = ""


func content_hash(catalog: DialogueCatalog) -> String:
	var terms: Array = []
	var dialogues: Array = []
	for id in catalog.get_term_ids():
		terms.append(catalog.get_term(StringName(id)))
	for id in catalog.get_dialogue_ids():
		var dialogue := catalog.get_dialogue(StringName(id))
		# Чистое оформление речи не меняет совместимость знаний/источников v1.
		for node in dialogue.nodes:
			node.text = DialogueText.plain(str(node.text))
		dialogues.append(dialogue)
	return JSON.stringify([terms, dialogues, HomeState.OBJECTS, HomeState.EVENTS]).sha256_text()


func encode(number: int, journal: Journal, home: HomeState, catalog: DialogueCatalog) -> Dictionary:
	last_error = ""
	if journal == null or home == null or catalog == null or not journal.matches_catalog(catalog):
		last_error = "Не удалось подготовить данные автосохранения."
		return {}
	var data := {"kind": "dark_alone_shift_checkpoint", "version": VERSION, "content_hash": content_hash(catalog), "shift": number, "saved_at_utc": Time.get_datetime_string_from_system(true), "journal": journal.export_progress(), "home": home.export_progress()}
	if decode(data, catalog).is_empty():
		return {}
	return data


func decode(data: Variant, catalog: DialogueCatalog) -> Dictionary:
	last_error = "Автосохранение повреждено или имеет неизвестный формат."
	if catalog == null or not catalog.is_loaded() or not data is Dictionary or data.size() != 7:
		return {}
	if data.get("kind") != "dark_alone_shift_checkpoint" or not _integer(data.get("version"), VERSION, VERSION):
		return {}
	if data.get("content_hash") != content_hash(catalog):
		last_error = "Автосохранение создано для другого набора игровых данных."
		return {}
	if not _integer(data.get("shift"), 2, 1000000) or not data.get("saved_at_utc") is String or data.saved_at_utc.length() > 64 or data.saved_at_utc.is_empty() or not data.get("journal") is Dictionary or not data.get("home") is Dictionary:
		return {}
	var journal := Journal.new()
	journal.configure(catalog)
	var home := HomeState.new()
	if not journal.restore_progress(data.journal) or not home.restore_progress(data.home):
		return {}
	for entry in journal.get_entries():
		var source: Dictionary = entry.source
		if source.is_empty():
			continue
		if source.shift >= int(data.shift):
			return {}
		var node := catalog.get_node(StringName(source.dialogue_id), StringName(source.node_id))
		if node.is_empty() or node.speaker != source.speaker:
			return {}
		var granted := false
		for effect in node.get("effects", []):
			if effect.type == "grant_term" and effect.term_id == entry.id:
				granted = true
		if not granted:
			return {}
	last_error = ""
	return {"journal": journal, "home_state": home, "shift": int(data.shift), "saved_at_utc": data.saved_at_utc}


func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and float(value) == floorf(float(value))
