class_name ServiceGuest
extends DialogueTrigger
## Заменяемая low-poly-заготовка гостя; состояние заказа хранит GuestService.

@export var guest_id: StringName = &"test_guest"


func show_served(drink_title: String) -> void:
	$ServedGlass.visible = true
	$Marker/Label.text = "[TEST] Гость · напиток подан"
	$ServedGlass/Label.text = drink_title


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


func get_prompt() -> String:
	return "E — поговорить с [TEST] гостем"
