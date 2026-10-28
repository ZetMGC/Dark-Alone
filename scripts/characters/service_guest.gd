class_name ServiceGuest
extends DialogueTrigger
signal drink_presented
## Заменяемая low-poly-заготовка гостя; состояние заказа хранит GuestService.

@export var guest_id: StringName = &"test_guest"

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
	if motion_available:
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
	var height := 0.10 if shot else 0.18
	var radius := 0.06 if shot else 0.075
	# Точка столешницы приходит от Main и не зависит от поворота гостя.
	$ServedGlass.global_position = surface_position + Vector3.UP * height / 2
	var glass := CylinderMesh.new()
	glass.height = height
	glass.top_radius = radius
	glass.bottom_radius = radius * 0.85
	glass.radial_segments = 12
	$ServedGlass/Cup.mesh = glass
	var transparent := StandardMaterial3D.new()
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	transparent.albedo_color = Color(0.65, 0.75, 0.7, 0.2)
	transparent.roughness = 0.25
	$ServedGlass/Cup.material_override = transparent
	var bottom := -height / 2 + 0.005
	for index in result.layers.size():
		var layer: Dictionary = result.layers[index]
		var liquid := MeshInstance3D.new()
		liquid.name = "DrinkLayer%d" % index
		var mesh := CylinderMesh.new()
		mesh.height = (height - 0.01) * float(layer.volume_ml) / float(result.vessel.capacity_ml)
		mesh.top_radius = radius * 0.86
		mesh.bottom_radius = radius * 0.82
		mesh.radial_segments = 12
		liquid.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(layer.color[0], layer.color[1], layer.color[2])
		material.roughness = 0.4
		liquid.material_override = material
		liquid.position.y = bottom + mesh.height / 2
		bottom += mesh.height
		$ServedGlass.add_child(liquid)
	if float(result.get("technique", {}).get("ice_ml", 0)) > 0:
		for index in 3:
			var cube := MeshInstance3D.new()
			cube.name = "DrinkIce%d" % index
			var mesh := BoxMesh.new()
			mesh.size = Vector3.ONE * (0.025 if shot else 0.035)
			cube.mesh = mesh
			var ice := StandardMaterial3D.new()
			ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ice.albedo_color = Color(0.65, 0.85, 0.92, 0.75)
			cube.material_override = ice
			cube.position = Vector3((index - 1) * radius * 0.45, minf(height / 2 - 0.015, bottom), 0)
			$ServedGlass.add_child(cube)
	$ServedGlass/Label.text = "Напиток подан · шот" if shot else "Напиток подан · стакан"
	drink_presented.emit()


func get_prompt() -> String:
	if not motion_available:
		return "[TEST] Гость идёт к своему месту" if visible else ""
	return "E — поговорить с [TEST] гостем"
