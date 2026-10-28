extends Interactable3D
## Готовая порция: одна модель и одна неизменяемая перед подачей смесь.
var carrier: Node
var preparation: DrinkPreparation
var held: bool = false
var materials: Array[StandardMaterial3D] = []

func setup(owner_node: Node, portion: DrinkPreparation) -> void:
	carrier = owner_node
	preparation = portion
	context_title = "Готовый напиток"
	context_description = "%d мл" % portion.get_volume_ml()
	context_anchor = self
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	var shot: bool = portion.get_vessel().id == "test_shot"
	var height := 0.10 if shot else 0.18
	var radius := 0.05 if shot else 0.068
	var glass := CylinderMesh.new()
	glass.height = height
	glass.top_radius = radius
	glass.bottom_radius = radius * 0.85
	var glass_material := _material(Color(0.70, 0.82, 0.85, 0.20))
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_material.render_priority = 101
	_mesh("Glass", glass, glass_material, Vector3(0, height * 0.5, 0))
	var view := portion.get_view()
	var bottom := 0.006
	var capacity: float = view.vessel.capacity_ml
	for index in view.layers.size():
		var layer: Dictionary = view.layers[index]
		var liquid := CylinderMesh.new()
		liquid.height = (height - 0.014) * float(layer.volume_ml) / capacity
		liquid.top_radius = radius * 0.92
		liquid.bottom_radius = radius * 0.78
		var color: Array = layer.color
		_mesh("Layer%d" % index, liquid, _material(Color(color[0], color[1], color[2])), Vector3(0, bottom + liquid.height * 0.5, 0))
		bottom += liquid.height
	var rim := TorusMesh.new()
	rim.inner_radius = radius - 0.002
	rim.outer_radius = radius + 0.001
	_mesh("Rim", rim, _material(Color(0.73, 0.80, 0.79)), Vector3(0, height, 0))
	if float(view.technique.ice_ml) > 0:
		for index in 3:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE * (0.016 if shot else 0.025)
			_mesh("Ice%d" % index, cube, _material(Color(0.67, 0.85, 0.89)), Vector3((index - 1) * radius * 0.5, minf(bottom, height - 0.02), 0))
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius + 0.025
	capsule.height = height + 0.04
	shape.shape = capsule
	shape.position.y = height * 0.5
	add_child(shape)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.24
	materials.append(material)
	return material

func _mesh(id: String, mesh: Mesh, material: Material, offset: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = mesh
	node.material_override = material
	node.position = offset
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func set_held(value: bool) -> void:
	held = value
	collision_layer = 0 if value else 2
	for material in materials:
		material.no_depth_test = value
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if value else BaseMaterial3D.SHADING_MODE_PER_PIXEL

func is_available() -> bool:
	return not held and is_instance_valid(carrier) and carrier.can_pick_up()

func get_prompt() -> String:
	return "E — взять напиток"

func interact() -> void:
	if is_available():
		carrier.pick_up()
