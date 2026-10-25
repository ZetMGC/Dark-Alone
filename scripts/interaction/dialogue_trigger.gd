class_name DialogueTrigger
extends Interactable3D
## Техническая точка разговора; позже её может заменить гость.

signal dialogue_requested(dialogue_id: StringName)

@export var dialogue_id: StringName = &"test_guest_intro"
@export var required_anchor: StringName = &"counter"
var _available: bool = false


func set_available(value: bool) -> void:
	_available = value
	set_collision_layer_value(2, value)
	$Marker.visible = value


func is_available() -> bool:
	return _available


func get_prompt() -> String:
	return "E — [TEST] начать разговор"


func interact() -> void:
	if _available:
		dialogue_requested.emit(dialogue_id)
