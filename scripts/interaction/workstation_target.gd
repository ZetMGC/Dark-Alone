class_name WorkstationTarget
extends Interactable3D
## Логическая цель реальной поверхности; коллизия остаётся у мебели.

signal activated
var available: bool = false
var prompt: String = "E — открыть стойку"
var blocked_prompt: String = "Рабочее место — за стойкой, напротив посетителя"


func is_available() -> bool:
	return available


func get_prompt() -> String:
	return prompt


func get_unavailable_prompt() -> String:
	return blocked_prompt


func interact() -> void:
	if available:
		activated.emit()
