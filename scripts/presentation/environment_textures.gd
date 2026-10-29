extends RefCounted
## Общие исходные текстуры; цвет/свет остаются параметрами конкретного помещения.
const WOOD = preload("res://assets/textures/environment/walnut_v1.png")
const PLASTER = preload("res://assets/textures/environment/plaster_v1.png")
const FABRIC = preload("res://assets/textures/environment/upholstery_v1.png")

static func apply(material: ShaderMaterial, surface: String) -> void:
	var texture: Texture2D
	var average: Vector3
	var meters: Vector2
	match surface:
		"wood":
			texture = WOOD
			average = Vector3(0.40, 0.35, 0.29)
			meters = Vector2(0.75, 1.5)
		"plaster":
			texture = PLASTER
			average = Vector3(0.70, 0.67, 0.61)
			meters = Vector2(2, 2)
		"fabric":
			texture = FABRIC
			average = Vector3(0.58, 0.55, 0.50)
			meters = Vector2(0.65, 0.65)
		_:
			return
	material.set_shader_parameter("detail_albedo", texture)
	material.set_shader_parameter("detail_average", average)
	material.set_shader_parameter("detail_meters", meters)
	material.set_shader_parameter("detail_enabled", true)
