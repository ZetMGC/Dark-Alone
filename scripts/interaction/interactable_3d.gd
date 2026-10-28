class_name Interactable3D
extends Area3D
## Базовый контракт доступного действия в мире; конкретный тип задаёт поведение.


func is_available() -> bool:
	return false


func get_prompt() -> String:
	return ""


func get_unavailable_prompt() -> String:
	return ""


func interact() -> void:
	pass


# Пассивные сведения не требуют команды и не изменяют игровой мир.
var context_title: String = ""
var context_description: String = ""
var context_feedback: String = ""
var context_passive: bool = false
var context_anchor: Node3D

func get_context_actions() -> Array[Dictionary]:
	if context_passive or not is_available():
		return []
	var caption := get_prompt().trim_prefix("E — ").trim_prefix("E  ")
	var result: Array[Dictionary] = []
	if not caption.is_empty():
		result.append({"id": &"interact", "text": caption})
	return result

func activate_context_action(id: StringName) -> bool:
	if id != &"interact" or context_passive or not is_available():
		return false
	interact()
	return true
