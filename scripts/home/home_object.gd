class_name HomeObject
extends Interactable3D

signal inspect_requested(object_id: StringName)
@export var object_id: StringName
@export var required_anchor: StringName
@export var title: String
@export_multiline var description: String
var available: bool = false


func is_available() -> bool:
	return available


func get_prompt() -> String:
	return "E — осмотреть: " + title


func interact() -> void:
	if available:
		inspect_requested.emit(object_id)


func set_available(value: bool) -> void:
	available = value
	set_collision_layer_value(2, value)
