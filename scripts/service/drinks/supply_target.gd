extends Interactable3D
var store: Node
var supply_id: StringName
var return_slot: bool = false
var drawer: bool = false
var opened: bool = false
var held: bool = false
var contents: Node3D
func is_available() -> bool:
	return not held and store != null and store.available(self)
func get_prompt() -> String:
	if return_slot: return "E — поставить бутылку на полку"
	return ("E — закрыть ящик" if opened else "E — открыть ящик") if drawer else "E — взять предмет"
func interact() -> void:
	if not is_available(): return
	if return_slot:
		store.return_bottle()
	elif drawer:
		opened = not opened
		contents.visible = opened
		for child in get_children():
			if child is MeshInstance3D:
				child.position.x += 0.48 if opened else -0.48
		for child in contents.get_children():
			if child is Area3D: child.collision_layer = 2 if opened else 0
	else:
		store.take(self)
func set_held(value: bool) -> void:
	held = value
	collision_layer = 0 if value else 2
