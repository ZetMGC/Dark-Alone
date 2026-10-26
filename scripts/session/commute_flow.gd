class_name CommuteFlow
extends RefCounted
## Только порядок переходов между сменами, без UI/таймеров и сохранений.

signal state_changed(state: StringName)

const AT_WORK := &"at_work"
const TO_HOME := &"to_home"
const AT_HOME := &"at_home"
const TO_WORK := &"to_work"
const READY := &"ready"

var state: StringName:
	get: return _state
var trip_id: int:
	get: return _trip_id

var _state: StringName = AT_WORK
var _trip_id: int = 0
var _changing: bool = false


func start_home() -> bool:
	if _changing or _state != AT_WORK:
		return false
	_trip_id += 1
	_change(TO_HOME)
	return true


func start_work() -> bool:
	if _changing or _state != AT_HOME:
		return false
	_trip_id += 1
	_change(TO_WORK)
	return true


func complete(id: int) -> bool:
	if _changing or id != _trip_id or _state not in [TO_HOME, TO_WORK]:
		return false
	_change(AT_HOME if _state == TO_HOME else READY)
	return true


func _change(value: StringName) -> void:
	_changing = true
	_state = value
	state_changed.emit(value)
	_changing = false
