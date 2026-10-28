class_name InteractionController
extends Node
## Луч останавливается на ближайшем препятствии или доступной цели.

signal prompt_changed(prompt: String)

@export var reach: float = 15.0
var _pointer_position: Vector2 = Vector2.ZERO
var _has_pointer_sample: bool = false
var pointer_mode: bool = false:
	set(value):
		if pointer_mode != value:
			_has_pointer_sample = false
		pointer_mode = value
var _surfaces: Dictionary = {}

var _view: Camera3D
var hit_position: Vector3 = Vector3.ZERO
var _target: Interactable3D
var _enabled: bool = true
var _last_prompt: String = ""


func configure(view: Camera3D) -> void:
	_view = view
	_clear_pointer_sample()
	if not is_instance_valid(view) or not view.is_inside_tree():
		return
	if not view.get_viewport().size_changed.is_connected(_clear_pointer_sample):
		view.get_viewport().size_changed.connect(_clear_pointer_sample)


func _clear_pointer_sample() -> void:
	_has_pointer_sample = false


func _input(event: InputEvent) -> void:
	if pointer_mode and event is InputEventMouseMotion:
		_pointer_position = event.position
		_has_pointer_sample = true


func register_surface(body: CollisionObject3D, target: Interactable3D) -> bool:
	if not is_instance_valid(body) or not is_instance_valid(target):
		return false
	_surfaces[body.get_instance_id()] = weakref(target)
	return true


func get_target() -> Interactable3D:
	_refresh_target()
	return _target


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
	_refresh_target()
	return activate(_target)


func _physics_process(_delta: float) -> void:
	_refresh_target()


func _refresh_target() -> void:
	if not _enabled or not is_instance_valid(_view):
		_set_target(null)
		return
	var origin := _view.global_position
	var end := origin - _view.global_basis.z * reach
	if pointer_mode:
		var point := _pointer_position if _has_pointer_sample else _view.get_viewport().get_mouse_position()
		origin = _view.project_ray_origin(point)
		end = origin + _view.project_ray_normal(point) * reach
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3)
	query.collide_with_areas = true
	var hit := _view.get_world_3d().direct_space_state.intersect_ray(query)
	hit_position = hit.get("position", end)
	var collider := hit.get("collider") as CollisionObject3D
	var target := collider as Interactable3D
	if target == null and is_instance_valid(collider) and _surfaces.has(collider.get_instance_id()):
		target = (_surfaces[collider.get_instance_id()] as WeakRef).get_ref() as Interactable3D
	_set_target(target)


func _set_target(target: Interactable3D) -> void:
	_target = target
	var prompt := ""
	if is_instance_valid(target):
		prompt = target.get_prompt() if target.is_available() else target.get_unavailable_prompt()
	if prompt != _last_prompt:
		_last_prompt = prompt
		prompt_changed.emit(prompt)
