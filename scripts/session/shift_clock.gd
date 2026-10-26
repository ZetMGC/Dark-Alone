class_name ShiftClock
extends RefCounted
## Время от уникальных завершённых событий, без привязки к реальным секундам.

signal progress_changed(remaining: int, budget: int)
signal shift_finished

var remaining: int:
	get: return _budget - _spent
var budget: int:
	get: return _budget
var finished: bool:
	get: return _finished

var _configured: bool = false
var _budget: int = 0
var _spent: int = 0
var _finished: bool = false
var _mutating: bool = false
var _events: Dictionary = {}


func configure(time_budget: int) -> bool:
	if _configured or time_budget <= 0:
		return false
	_budget = time_budget
	_configured = true
	return true


func apply_completed_event(event_id: StringName, time_cost: int) -> bool:
	if not _configured or _mutating or _finished or time_cost < 0 or str(event_id).strip_edges().is_empty() or _events.has(event_id):
		return false
	_mutating = true
	_events[event_id] = {"id": str(event_id), "time_cost": time_cost}
	_spent = _budget if time_cost >= remaining else _spent + time_cost
	_finished = _spent == _budget
	progress_changed.emit(remaining, _budget)
	if _finished:
		shift_finished.emit()
	_mutating = false
	return true


func get_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in _events.values():
		result.append(event.duplicate(true))
	return result
