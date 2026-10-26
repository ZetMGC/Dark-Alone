extends Node3D
## Декоративный проход: не меняет коллизии, якоря или игровые данные.

const SURFACE = preload("res://assets/shaders/worn_surface.gdshader")
var _wood: ShaderMaterial
var _iron: StandardMaterial3D


func _ready() -> void:
	var geometry := get_parent().get_node("Geometry")
	var plaster := _material(Color(0.39, 0.4, 0.38), 0)
	var tile := _material(Color(0.36, 0.37, 0.34), 1)
	_wood = _material(Color(0.26, 0.25, 0.22), 2)
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.09, 0.105, 0.1)
	_iron.roughness = 0.85
	for child in geometry.get_children():
		if not child is MeshInstance3D:
			continue
		if str(child.name).ends_with("Wall"):
			child.material_override = plaster
		elif child.name == &"Floor":
			child.material_override = tile
		elif str(child.name).begins_with("Counter") or str(child.name).begins_with("Shelf") or child.name in [&"Bench", &"BenchBack", &"TableTop"]:
			child.material_override = _wood
	geometry.get_node("SignCaption").text = "[TEST]   Н О Ч Н А Я   С М Е Н А"
	geometry.get_node("SignCaption").modulate = Color(0.6, 0.62, 0.58)
	# Нижние панели, фризы и плинтус разделяют крупные плоскости.
	for x in range(-5, 6):
		_box(Vector3(x, 0.62, -6.82), Vector3(0.94, 1.18, 0.08), _wood)
		_box(Vector3(x, 1.27, -6.78), Vector3(0.98, 0.06, 0.12), _iron)
	for z in range(-6, 5):
		for x in [-5.82, 5.82]:
			_box(Vector3(x, 0.62, z), Vector3(0.09, 1.18, 0.94), _wood)
			_box(Vector3(x, 1.27, z), Vector3(0.12, 0.06, 0.98), _iron)
	_box(Vector3(0, 0.08, -6.76), Vector3(11.7, 0.16, 0.12), _iron)
	for x in [-5.78, 5.78]:
		_box(Vector3(x, 0.08, -1), Vector3(0.12, 0.16, 11.6), _iron)
	# Балки, вентиляционная решётка, обрамление двери и окна.
	for z in [-5.0, -1.0, 3.0]:
		_box(Vector3(0, 3.42, z), Vector3(11.8, 0.18, 0.16), _iron)
	for x in [-0.88, 0.88]:
		_box(Vector3(x, 1.25, 4.71), Vector3(0.12, 2.5, 0.15), _wood)
	_box(Vector3(0, 2.52, 4.71), Vector3(1.9, 0.12, 0.15), _wood)
	_box(Vector3(0.52, 1.1, 4.7), Vector3(0.24, 0.035, 0.05), _iron)
	_box(Vector3(-3.35, 2.65, -6.72), Vector3(1.25, 0.62, 0.08), _iron)
	for index in 8:
		_box(Vector3(-3.35, 2.4 + index * 0.07, -6.65), Vector3(1.12, 0.025, 0.08), _wood)
	for z in [-5.6, -2.0]:
		_box(Vector3(5.72, 2, z), Vector3(0.15, 2.02, 0.12), _iron)
	for y in [1.02, 2.98]:
		_box(Vector3(5.72, y, -3.8), Vector3(0.15, 0.12, 3.72), _iron)
	# Простые табуреты и неинтерактивные предметы.
	for z in [-3.5, 0.7]:
		_stool(Vector3(-1.95, 0, z))
	_box(Vector3(-3.2, 1.18, -2.8), Vector3(0.62, 0.035, 0.36), _iron)
	_box(Vector3(3.7, 0.91, -2.7), Vector3(0.22, 0.025, 0.3), plaster)
	# Панели передней стенки стойки.
	for index in 8:
		_box(Vector3(-3.025, 0.5, -4.2 + index * 0.72), Vector3(0.05, 0.8, 0.64), _wood)
	_style_bottles()
	_style_light()


func _material(color: Color, kind: int) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SURFACE
	result.set_shader_parameter("tint", color)
	result.set_shader_parameter("surface_kind", kind)
	return result


func _box(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node


func _stool(at: Vector3) -> void:
	_box(at + Vector3(0, 0.68, 0), Vector3(0.48, 0.09, 0.48), _wood)
	for x in [-0.17, 0.17]:
		for z in [-0.17, 0.17]:
			_box(at + Vector3(x, 0.32, z), Vector3(0.045, 0.64, 0.045), _iron)


func _style_bottles() -> void:
	for node in get_parent().get_node("Props").get_children():
		if not str(node.name).begins_with("Bottle"):
			continue
		var bottle := StandardMaterial3D.new()
		bottle.albedo_color = Color(0.15, 0.17, 0.14)
		bottle.roughness = 0.65
		node.material_override = bottle
		_box(node.position + Vector3(0.0, 0.13, 0.0), Vector3(0.05, 0.18, 0.05), bottle)


func _style_light() -> void:
	var level := get_parent()
	var environment: Environment = level.get_node("WorldEnvironment").environment.duplicate()
	level.get_node("WorldEnvironment").environment = environment
	environment.background_color = Color(0.025, 0.03, 0.032)
	environment.ambient_light_color = Color(0.48, 0.51, 0.51)
	environment.ambient_light_energy = 0.46
	level.get_node("Fill").light_energy = 0.12
	var counter := level.get_node("Lights/CounterLight") as OmniLight3D
	counter.light_color = Color(0.9, 0.83, 0.65)
	counter.light_energy = 2.0
	counter.omni_range = 6.0
	var table := level.get_node("Lights/TableLight") as OmniLight3D
	table.light_color = Color(0.62, 0.69, 0.7)
	table.light_energy = 1.4
	var entry := level.get_node("Lights/EntryLight") as OmniLight3D
	entry.light_color = Color(0.57, 0.63, 0.65)
	entry.light_energy = 0.85
