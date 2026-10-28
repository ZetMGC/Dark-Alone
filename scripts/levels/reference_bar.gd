class_name ReferenceBar
extends Node3D
## План 10×8 м: север −Z. Самостоятельная сцена, старый graybox сохранён.

var geometry: Node3D
var wood: Material
var plaster: Material
var brass: Material
var leather: Material
var tile: Material
var dark: Material


func _ready() -> void:
	geometry = Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	wood = material(Color(0.28, 0.16, 0.075), 2)
	plaster = material(Color(0.31, 0.28, 0.21), 0)
	brass = material(Color(0.43, 0.32, 0.14), 0)
	leather = material(Color(0.19, 0.065, 0.035), 3)
	tile = material(Color(0.29, 0.30, 0.26), 1)
	dark = material(Color(0.065, 0.055, 0.038), 0)
	box("Foundation", Vector3(0, -0.12, 0), Vector3(10, 0.24, 8), dark)
	for row in 32:
		for col in 5:
			box("Plank", Vector3(-4 + col * 2, 0.012, -3.875 + row * 0.25), Vector3(1.985, 0.025, 0.238), wood, false)
	box("Ceiling", Vector3(0, 2.94, 0), Vector3(10, 0.16, 8), dark, false)
	wall_z("North", -4, -5, 5, 4.1, 0.85)
	box("RearVestibuleFloor", Vector3(4.1, -0.1, -4.5), Vector3(1.1, 0.2, 1), tile)
	wall_x("RearVestibuleLeft", 3.55, -5, -4)
	wall_x("RearVestibuleRight", 4.65, -5, -4)
	wall_z("RearVestibuleEnd", -5, 3.55, 4.65)
	box("RearExternalDoor", Vector3(4.1, 1.05, -4.92), Vector3(0.85, 2.1, 0.08), wood, false)
	wall_x("West", -5, -4, 4)
	wall_x("East", 5, -4, 4)
	wall_z("South", 4, -5, 5, -0.6, 0.95)
	wall_z("KitchenFront", -1.0, 1.5, 3.0, 2.2, 0.9)
	wall_x("BarKitchen", 1.5, -4, -1, -2.5, 0.9)
	wall_x("StoreWall", 3, -4, -1, -2.5, 0.9)
	wall_z("StoreFront", -1, 3, 5)
	# Два независимых проёма из зала.
	wall_x("WCOne", 3, -1, 0.45, -0.25, 0.85)
	wall_x("WCTwo", 3, 0.45, 1.9, 1.15, 0.85)
	wall_z("WCDivider", 0.45, 3, 5)
	wall_z("StaffFront", 1.9, 1.6, 5, 2.25, 0.9)
	wall_x("StaffSide", 1.6, 1.9, 4)
	wall_x("VestibuleLeft", -1.5, 2.8, 4)
	wall_x("VestibuleRight", 0.35, 2.8, 4)
	wall_z("VestibuleFront", 2.8, -1.5, 0.35, -0.6, 0.95)
	box("EntranceDoor", Vector3(-0.6, 1.05, 4), Vector3(0.95, 2.1, 0.08), wood)
	room_floor(Vector3(2.25, 0.035, -2.5), Vector3(1.45, 0.03, 2.9))
	room_floor(Vector3(4, 0.035, 0.45), Vector3(1.9, 0.03, 2.8))
	room_floor(Vector3(-0.6, 0.035, 3.4), Vector3(1.7, 0.03, 1.1))
	box("CounterBase", Vector3(-0.3, 0.5, -1.2), Vector3(3.15, 1, 0.62), dark)
	box("CounterTop", Vector3(-0.3, 1.08, -1.2), Vector3(3.4, 0.16, 0.78), wood)
	box("CounterReturn", Vector3(-1.85, 0.5, -2.45), Vector3(0.5, 1, 2.4), dark)
	box("ReturnTop", Vector3(-1.85, 1.08, -2.45), Vector3(0.65, 0.16, 2.4), wood)
	for x in [-1.5, -0.85, 0.55, 1.2]:
		stool(Vector3(x, 0, -0.35))
	for x in [-1.55, -0.8, 0, 0.75]:
		box("CounterPanel", Vector3(x, 0.52, -0.876), Vector3(0.66, 0.72, 0.025), wood, false)
	box("FootRail", Vector3(-0.3, 0.22, -0.64), Vector3(3.1, 0.035, 0.035), brass, false)
	box("ShelfBack", Vector3(-0.25, 1.95, -3.88), Vector3(3.1, 1.6, 0.12), dark)
	box("ShelfLower", Vector3(-0.25, 1.65, -3.66), Vector3(3.1, 0.08, 0.42), wood)
	box("ShelfUpper", Vector3(-0.25, 2.25, -3.66), Vector3(3.1, 0.08, 0.42), wood)
	for shelf_y in [1.86, 2.46]:
		for i in 17:
			var pos := Vector3(-1.65 + i * 0.17, shelf_y, -3.65)
			cylinder("Bottle", pos, 0.047, 0.28, material(Color(0.11 + (i % 3) * 0.06, 0.18, 0.09), 0))
			cylinder("Neck", pos + Vector3.UP * 0.18, 0.02, 0.12, brass)
	for z in [-2.7, 1.55]:
		sofa(Vector3(-4.5, 0, z))
		table(Vector3(-3.45, 0, z), Vector2(1.0, 1.2))
	table(Vector3(-3.45, 0, -0.5), Vector2(0.9, 0.9))
	table(Vector3(-1.6, 0, 1.4), Vector2(0.85, 0.9))
	table(Vector3(1.4, 0, 0.8), Vector2(0.9, 0.9))
	table(Vector3(-2.8, 0, 3.25), Vector2(0.85, 0.7))
	for pos in [Vector3(-3.45, 0, -1.85), Vector3(-3.45, 0, 2.4), Vector3(-2.65, 0, -0.5), Vector3(-1.6, 0, 2.1), Vector3(2.15, 0, 0.8), Vector3(-2.8, 0, 2.65)]:
		chair(pos)
	# Кухня, склад, санузлы и персонал.
	box("KitchenBench", Vector3(2.25, 0.48, -3.62), Vector3(1.2, 0.96, 0.55), wood)
	box("Sink", Vector3(2.0, 1, -3.6), Vector3(0.45, 0.07, 0.4), brass, false)
	box("Hob", Vector3(2.65, 1, -3.6), Vector3(0.38, 0.04, 0.4), dark, false)
	for x in [3.3, 4.65]:
		for z in [-3.45, -1.5]:
			for y in [0.25, 0.75]:
				box("SupplyCrate", Vector3(x, y, z), Vector3(0.48, 0.48, 0.65), wood)
	for z in [-0.3, 1.15]:
		cylinder("ToiletBowl", Vector3(4.55, 0.28, z), 0.24, 0.5, plaster)
		box("Cistern", Vector3(4.75, 0.68, z), Vector3(0.26, 0.4, 0.45), plaster)
		box("Basin", Vector3(3.55, 0.85, z - 0.42), Vector3(0.45, 0.12, 0.38), plaster)
	box("StaffBed", Vector3(4.35, 0.3, 3.35), Vector3(1.05, 0.6, 1.7), wood)
	box("Blanket", Vector3(4.35, 0.66, 3.55), Vector3(1.02, 0.14, 1.2), leather, false)
	box("Pillow", Vector3(4.35, 0.72, 2.75), Vector3(0.8, 0.16, 0.38), plaster, false)
	box("Locker", Vector3(1.97, 0.95, 3.5), Vector3(0.55, 1.9, 0.6), wood)
	box("StaffTable", Vector3(3, 0.7, 2.35), Vector3(0.7, 0.12, 0.6), wood)
	# Деревянные панели и рамы связывают интерьер с референсом.
	for z in [-3.5, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5]:
		box("WallPanel", Vector3(-4.91, 0.5, z), Vector3(0.05, 0.95, 0.93), wood, false)
	box("PanelRail", Vector3(-4.86, 1.02, 0), Vector3(0.09, 0.07, 7.9), brass, false)
	for z in [-1.45, 1.35]:
		box("PictureFrame", Vector3(-4.87, 1.8, z), Vector3(0.10, 0.55, 0.40), brass, false)
		box("Picture", Vector3(-4.80, 1.8, z), Vector3(0.015, 0.43, 0.30), leather, false)
	for pos in [Vector3(-4.4, 0, -3.6), Vector3(-4.4, 0, 3.5), Vector3(4.6, 0, -3.5)]:
		cylinder("PlantPot", pos+Vector3.UP*0.24, 0.18, 0.48, dark)
		for i in 7:
			var leaf := box("PlantLeaf", pos+Vector3(sin(i)*0.13, 0.70 + (i%3)*0.09, cos(i)*0.13), Vector3(0.09, 0.62, 0.025), material(Color(0.14, 0.22, 0.08), 0), false)
			leaf.rotation = Vector3(cos(i)*0.5, i, sin(i)*0.5)
	for x in [-3.6, 2.7]:
		window_panel(Vector3(x, 1.8, 3.87))
	window_panel(Vector3(-3.5, 1.8, -3.87))
	for z in [-2.8, 0, 2.7]:
		var window := window_panel(Vector3(-4.87, 1.8, z))
		window.rotation.y = PI / 2
	for x in [-4.9, -1.95, 1.5, 4.9]:
		box("Beam", Vector3(x, 2.78, 0), Vector3(0.12, 0.20, 8), wood, false)
	for pos in [Vector3(-3.4, 2.5, -2.7), Vector3(-3.4, 2.5, 1.5), Vector3(-1.6, 2.5, 1.4), Vector3(1.4, 2.5, 0.8), Vector3(-1.2, 2.5, -1.2), Vector3(0.7, 2.5, -1.2), Vector3(2.2, 2.5, -2.5), Vector3(4, 2.5, -2.5), Vector3(4, 2.5, 0.5), Vector3(3, 2.5, 3), Vector3(-0.6, 2.5, 3.4)]:
		lamp(pos)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.04, 0.045, 0.05)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.58, 0.55, 0.48)
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	var anchors := Node3D.new()
	anchors.name = "Anchors"
	add_child(anchors)
	for data in [["entry", Vector3(-1.1, 1.65, 2.1), 0.0, ["counter", "corner"]], ["counter", Vector3(-0.2, 1.65, -2.2), PI, ["entry", "table"]], ["table", Vector3(-2.5, 1.65, 0.5), 0.0, ["counter", "corner"]], ["corner", Vector3(0.7, 1.65, 2.1), 0.0, ["entry", "table"]]]:
		var anchor := preload("res://scenes/navigation/anchor_point.tscn").instantiate()
		anchor.name = data[0].capitalize()
		anchor.anchor_id = StringName(data[0])
		anchor.display_name = data[0]
		anchor.position = data[1]
		anchor.rotation.y = data[2]
		anchor.neighbours = PackedStringArray(data[3])
		anchors.add_child(anchor)


func material(color: Color, kind: int) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://assets/shaders/worn_surface.gdshader")
	result.set_shader_parameter("tint", color)
	result.set_shader_parameter("surface_kind", kind)
	return result


func box(label: String, pos: Vector3, size: Vector3, mat: Material, solid: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = BoxMesh.new()
	mesh.material_override = mat
	mesh.position = pos
	mesh.scale = size
	geometry.add_child(mesh, true)
	if solid:
		var body := StaticBody3D.new()
		body.name = "Body"
		var collision := CollisionShape3D.new()
		collision.shape = BoxShape3D.new()
		body.add_child(collision)
		mesh.add_child(body)
	return mesh


func wall_z(label: String, z: float, a: float, b: float, doorway: float = 99, width: float = 0.9) -> void:
	if doorway == 99:
		box(label, Vector3((a+b)/2, 1.4, z), Vector3(b-a, 2.8, 0.14), plaster)
	else:
		wall_z(label + "L", z, a, doorway-width/2)
		wall_z(label + "R", z, doorway+width/2, b)
		box(label + "Lintel", Vector3(doorway, 2.45, z), Vector3(width, 0.7, 0.14), wood)
		var leaf := box(label + "OpenDoor", Vector3(doorway-width/2, 1.05, z+width/2), Vector3(0.05, 2.1, width), wood)
		leaf.rotation.y = -0.12


func wall_x(label: String, x: float, a: float, b: float, doorway: float = 99, width: float = 0.9) -> void:
	if doorway == 99:
		box(label, Vector3(x, 1.4, (a+b)/2), Vector3(0.14, 2.8, b-a), plaster)
	else:
		wall_x(label + "L", x, a, doorway-width/2)
		wall_x(label + "R", x, doorway+width/2, b)
		box(label + "Lintel", Vector3(x, 2.45, doorway), Vector3(0.14, 0.7, width), wood)
		box(label + "OpenDoor", Vector3(x+width/2, 1.05, doorway-width/2), Vector3(width, 2.1, 0.05), wood)


func cylinder(label: String, pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 12
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = pos
	geometry.add_child(mesh)


func stool(pos: Vector3) -> void:
	cylinder("StoolSeat", pos + Vector3.UP * 0.76, 0.18, 0.09, leather)
	box("StoolLegs", pos + Vector3.UP * 0.36, Vector3(0.25, 0.72, 0.25), wood)


func chair(pos: Vector3) -> void:
	box("ChairSeat", pos + Vector3.UP * 0.46, Vector3(0.45, 0.12, 0.43), wood)
	box("ChairBack", pos + Vector3(0, 0.78, 0.19), Vector3(0.45, 0.55, 0.06), wood)
	for x in [-0.16, 0.16]:
		for z in [-0.16, 0.16]:
			box("ChairLeg", pos+Vector3(x, 0.2, z), Vector3(0.05, 0.4, 0.05), wood, false)


func sofa(pos: Vector3) -> void:
	box("SofaBase", pos+Vector3(0, 0.25, 0), Vector3(0.7, 0.5, 1.9), wood)
	box("SofaBack", pos+Vector3(-0.25, 0.7, 0), Vector3(0.2, 0.65, 1.9), leather)
	for z in [-0.6, 0, 0.6]:
		box("Cushion", pos+Vector3(0.05, 0.54, z), Vector3(0.53, 0.16, 0.56), leather, false)


func table(pos: Vector3, size: Vector2) -> void:
	box("TableTop", pos+Vector3.UP*0.78, Vector3(size.x, 0.10, size.y), wood)
	for x in [-size.x*0.35, size.x*0.35]:
		for z in [-size.y*0.35, size.y*0.35]:
			box("TableLeg", pos+Vector3(x, 0.36, z), Vector3(0.08, 0.72, 0.08), wood, false)
	cylinder("CandleHolder", pos+Vector3.UP*0.86, 0.07, 0.06, brass)


func room_floor(pos: Vector3, size: Vector3) -> void:
	box("TileFloor", pos, size, tile, false)


func window_panel(pos: Vector3) -> MeshInstance3D:
	var frame := box("WindowFrame", pos, Vector3(1.25, 1.25, 0.10), wood, false)
	var glass := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.85, 0.82, 1.1)
	glass.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.18, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.08, 0.11)
	glass.material_override = mat
	frame.add_child(glass)
	return frame


func lamp(pos: Vector3) -> void:
	cylinder("LampShade", pos, 0.18, 0.14, brass)
	cylinder("LampCable", Vector3(pos.x, 2.7, pos.z), 0.009, 0.4, dark)
	var light := OmniLight3D.new()
	light.position = pos - Vector3.UP * 0.13
	light.light_color = Color(1, 0.72, 0.40)
	light.light_energy = 1.1
	light.omni_range = 3.3
	light.shadow_enabled = true
	add_child(light)
