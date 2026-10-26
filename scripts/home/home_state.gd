class_name HomeState
extends RefCounted
## Прогресс исследования только в памяти; определения не являются сюжетом.

signal changed
const OBJECTS: Array[StringName] = [&"home_desk", &"home_window", &"home_bed", &"home_door"]
const EVENTS := {
	&"test_home_observation": {
		"title": "[TEST] Сопоставить наблюдения",
		"description": "[TEST] Осмотрены стол и окно. Здесь можно подключить отдельное домашнее событие: текст, выбор и последствия. Сейчас меняется только техническая отметка события; сюжета и награды нет.",
		"requires": [&"home_desk", &"home_window"]
	}
}
var _observed: Dictionary = {}
var _resolved: Dictionary = {}
var _changing: bool = false


func has_observed(id: StringName) -> bool:
	return _observed.has(id)


func observe(id: StringName) -> bool:
	if _changing or id not in OBJECTS or has_observed(id):
		return false
	_changing = true
	_observed[id] = true
	changed.emit()
	_changing = false
	return true


func get_observed_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in OBJECTS:
		if has_observed(id):
			ids.append(id)
	return ids


func get_available_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: StringName in EVENTS:
		if _resolved.has(id):
			continue
		var available := true
		for required: StringName in EVENTS[id].requires:
			if not has_observed(required):
				available = false
		if available:
			var event: Dictionary = EVENTS[id].duplicate(true)
			event["id"] = id
			result.append(event)
	return result


func resolve_event(id: StringName) -> bool:
	if _changing:
		return false
	for event in get_available_events():
		if event.id == id:
			_changing = true
			_resolved[id] = true
			changed.emit()
			_changing = false
			return true
	return false


func has_resolved(id: StringName) -> bool:
	return _resolved.has(id)
