class_name ServiceGuest
extends DialogueTrigger
signal drink_presented
## Заменяемая low-poly-заготовка гостя; состояние заказа хранит GuestService.

@export var guest_id: StringName = &"test_guest"

var carry_mode: bool = false
var carry_delivery: Callable

var _target_shape: CapsuleShape3D
var _walk_shape: CapsuleShape3D
var _target_size: Vector2
var _walk_size: Vector2
var _target_origin: Vector3
var _walk_origin: Vector3
var motion_available: bool = true


func is_available() -> bool:
	return motion_available and super.is_available()


func interact() -> void:
	if not motion_available:
		return
	if carry_mode:
		if is_available() and carry_delivery.is_valid():
			carry_delivery.call()
	else:
		super.interact()


func configure_body_scale(multiplier: float) -> bool:
	if not is_finite(multiplier) or multiplier <= 0:
		return false
	var target: CollisionShape3D = $Collision
	var walking: CollisionShape3D = $WalkObstacle/Shape
	if _target_shape == null:
		_target_shape = target.shape.duplicate() as CapsuleShape3D
		_walk_shape = walking.shape.duplicate() as CapsuleShape3D
		_target_size = Vector2(_target_shape.radius, _target_shape.height)
		_walk_size = Vector2(_walk_shape.radius, _walk_shape.height)
		_target_origin = target.position
		_walk_origin = walking.position
		target.shape = _target_shape
		walking.shape = _walk_shape
	_target_shape.radius = _target_size.x * multiplier
	_target_shape.height = _target_size.y * multiplier
	_walk_shape.radius = _walk_size.x * multiplier
	_walk_shape.height = _walk_size.y * multiplier
	var floor := Vector3(0, VisitorModel.FLOOR_Y, 0)
	target.position = floor + (_target_origin - floor) * multiplier
	walking.position = floor + (_walk_origin - floor) * multiplier
	$Marker.position.y = VisitorModel.FLOOR_Y * (1.0 - multiplier)
	return true


func get_dialogue_head_position() -> Vector3:
	return $Body.get_dialogue_head_position()


func get_dialogue_face_position() -> Vector3:
	return $Body.get_dialogue_face_position()


func show_served(drink_title: String) -> void:
	$ServedGlass.visible = true
	$Marker/Label.text = "[TEST] Гость · напиток подан"
	$ServedGlass/Label.text = drink_title
	drink_presented.emit()


func show_prepared(result: Dictionary, surface_position: Vector3) -> void:
	if result.is_empty():
		return
	for child in $ServedGlass.get_children():
		if str(child.name).begins_with("Drink"):
			$ServedGlass.remove_child(child)
			child.queue_free()
	$ServedGlass.visible = true
	var shot: bool = result.vessel.id == "test_shot"
	$ServedGlass/Cup.visible = false
	var visual := FacetedGlassVisual.new(shot)
	$ServedGlass.global_position = surface_position + Vector3.UP * visual.vessel_height / 2
	visual.name = "DrinkGlassVisual"
	$ServedGlass.add_child(visual)
	visual.position.y = -visual.vessel_height / 2
	visual.set_contents(result)
	$ServedGlass/Label.text = "Напиток подан · Кромка" if shot else "Напиток подан · Гранитоль"
	drink_presented.emit()


func get_prompt() -> String:
	if not motion_available:
		return "[TEST] Гость идёт к своему месту" if visible else ""
	return "E — подать напиток" if carry_mode else "E — поговорить с [TEST] гостем"
