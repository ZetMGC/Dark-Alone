class_name InteractionController
extends Node
## Луч останавливается на ближайшем препятствии или доступной цели.

signal prompt_changed(prompt: String)

@export var reach: float = 15.0

var _view: Camera3D
var _target: Interactable3D
var _enabled: bool = true
var _last_prompt: String = ""


func configure(view: Camera3D) -> void:
	_view = view


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_set_target(null)


func activate(target: Interactable3D) -> bool:
	if not _enabled or not is_instance_valid(target) or not target.is_available():
		return false
	target.interact()
	return true


func try_interact() -> bool:
	return activate(_target)


func _physics_process(_delta: float) -> void:
	if not _enabled or not is_instance_valid(_view):
		return
	var origin := _view.global_position
	var end := origin - _view.global_basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3)
	query.collide_with_areas = true
	var hit := _view.get_world_3d().direct_space_state.intersect_ray(query)
	var target := hit.get("collider") as Interactable3D
	if is_instance_valid(target) and target.is_available():
		_set_target(target)
	else:
		_set_target(null)


func _set_target(target: Interactable3D) -> void:
	_target = target
	var prompt := target.get_prompt() if is_instance_valid(target) else ""
	if prompt != _last_prompt:
		_last_prompt = prompt
		prompt_changed.emit(prompt)
