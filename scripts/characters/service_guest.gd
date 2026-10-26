class_name ServiceGuest
extends DialogueTrigger
## Заменяемая low-poly-заготовка гостя; состояние заказа хранит GuestService.

@export var guest_id: StringName = &"test_guest"


func show_served(drink_title: String) -> void:
	$ServedGlass.visible = true
	$Marker/Label.text = "[TEST] Гость · напиток подан"
	$ServedGlass/Label.text = drink_title


func get_prompt() -> String:
	return "E — поговорить с [TEST] гостем"
