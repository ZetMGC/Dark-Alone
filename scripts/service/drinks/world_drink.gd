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
	var visual := FacetedGlassVisual.new(shot)
	visual.name = "GlassVisual"
	add_child(visual)
	visual.set_contents(portion.get_view())
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = visual.vessel_height + 0.02
	shape.radius = visual.vessel_radius + 0.02
	collision.shape = shape
	collision.position.y = visual.vessel_height / 2
	add_child(collision)

func set_held(value: bool) -> void:
	held = value
	collision_layer = 0 if value else 2
	var visual := get_node_or_null("GlassVisual") as FacetedGlassVisual
	if visual != null: visual.set_held(value)
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
