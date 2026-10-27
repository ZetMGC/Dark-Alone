extends Interactable3D
## Логическое действие реальной мебели; собственной области попадания нет.

signal activated

var rig: FreeRoamCamera
var object: HomeObject
var context_allowed: Callable


func is_available() -> bool:
	if not context_allowed.is_valid() or not context_allowed.call():
		return false
	if rig.focus_active:
		return rig.current_anchor_id == object.required_anchor and object.is_available()
	return rig.can_move_to(object.required_anchor)


func get_prompt() -> String:
	return object.get_prompt() if rig.focus_active else "E — подойти: " + rig.get_anchor(object.required_anchor).display_name


func get_unavailable_prompt() -> String:
	return "Подойдите ближе к предмету" if context_allowed.is_valid() and context_allowed.call() and not rig.focus_active else ""


func interact() -> void:
	if is_available():
		activated.emit()
