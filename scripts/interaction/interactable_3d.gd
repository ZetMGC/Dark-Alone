class_name Interactable3D
extends Area3D
## Базовый контракт доступного действия в мире; конкретный тип задаёт поведение.


func is_available() -> bool:
	return false


func get_prompt() -> String:
	return ""


func interact() -> void:
	pass
