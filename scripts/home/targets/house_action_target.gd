extends Interactable3D
## Бытовое действие: доступно в ходьбе, по ближайшей реальной поверхности.

var allowed: Callable
var action: Callable
var caption: Callable


func is_available() -> bool:
	return allowed.is_valid() and allowed.call()


func get_prompt() -> String:
	return "E — " + str(caption.call())


func get_unavailable_prompt() -> String:
	return ""


func interact() -> void:
	if not context_passive and is_available() and action.is_valid():
		action.call()
