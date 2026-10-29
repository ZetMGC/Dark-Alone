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
var _flicker: SpotLight3D
var _light_time: float = 0.0


func _ready() -> void:
	geometry = Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	wood = material(Color(0.19, 0.155, 0.125), 2)
	plaster = material(Color(0.27, 0.28, 0.255), 0)
	brass = material(Color(0.30, 0.27, 0.19), 0)
	leather = material(Color(0.135, 0.10, 0.09), 3)
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
	wall_x("West", -5, -4, 4)
	wall_x("East", 5, -4, 4)
	wall_z("South", 4, -5, 5, -0.6, 0.95)
	wall_z("KitchenFront", -1.0, 1.5, 3.0, 2.2, 0.9, true)
	wall_x("BarKitchen", 1.5, -4, -1, -2.5, 0.9)
	wall_x("StoreWall", 3, -4, -1, -2.5, 0.9)
	wall_z("StoreFront", -1, 3, 5)
	# Два независимых проёма из зала.
	wall_x("WCOne", 3, -1, 0.45, -0.25, 0.85, true)
	wall_x("WCTwo", 3, 0.45, 1.9, 1.15, 0.85, true)
	wall_z("WCDivider", 0.45, 3, 5)
	wall_z("StaffFront", 1.9, 1.6, 5, 2.25, 0.9)
	wall_x("StaffSide", 1.6, 1.9, 4)
	wall_x("VestibuleLeft", -1.5, 2.8, 4)
	wall_x("VestibuleRight", 0.35, 2.8, 4)
	wall_z("VestibuleFront", 2.8, -1.5, 0.35, -0.6, 0.95, true)
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
	table(Vector3(-2.8, 0, 3.25), Vector2(0.85, 0.7))
	# Локальный −Z стула смотрит к своему столу; спинка остаётся снаружи.
	for placement in [[Vector3(-3.45, 0, -1.78), 0.0], [Vector3(-3.45, 0, 2.47), 0.0], [Vector3(-2.65, 0, -0.5), PI / 2], [Vector3(-1.6, 0, 2.18), 0.0], [Vector3(-2.8, 0, 2.56), PI]]:
		chair(placement[0], placement[1])
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
	# Световые островки: два стола остаются без собственной лампы.
	lamp(Vector3(-3.4, 2.5, -2.7), 1.8, 3.1)
	_flicker = lamp(Vector3(-3.4, 2.5, 1.5), 1.35, 3.0)
	lamp(Vector3(-1.6, 2.5, 1.4), 0.0, 2.4)
	lamp(Vector3(-1.2, 2.5, -1.2), 1.25, 3.0)
	lamp(Vector3(0.7, 2.5, -1.2), 1.25, 3.0)
	lamp(Vector3(2.2, 2.5, -2.5), 1.2, 3.1, Color(0.72, 0.86, 0.77))
	lamp(Vector3(4, 2.5, -2.5), 1.4, 3.0, Color(0.70, 0.78, 0.74))
	lamp(Vector3(4, 2.5, 0.5), 0.4, 2.0, Color(0.72, 0.80, 0.76))
	lamp(Vector3(3, 2.5, 3), 0.25, 2.0)
	lamp(Vector3(-0.6, 2.5, 3.4), 0.35, 2.1)
	# Узкий свет на полки/приготовление и мягкий отражённый свет на лицо гостя.
	spot("WorkbenchLight", Vector3(-0.3, 2.55, -2.65), Vector3(-0.3, 1.1, -3.35), Color(0.94, 0.79, 0.58), 1.1, 2.8, 55)
	spot("GuestFill", Vector3(-0.2, 2.2, -2.45), Vector3(-0.2, 1.45, -0.45), Color(0.90, 0.80, 0.65), 0.55, 3.1, 36)
	spot("WindowWest", Vector3(-4.72, 1.85, -0.2), Vector3(-2.3, 0.1, 0.7), Color(0.39, 0.53, 0.74), 1.8, 4.4, 42)
	spot("WindowNorth", Vector3(-3.5, 1.85, -3.70), Vector3(-2.8, 0.1, -1.2), Color(0.39, 0.53, 0.74), 1.4, 3.7, 34)
	spot("WindowSouth", Vector3(-3.6, 1.85, 3.70), Vector3(-2.6, 0.1, 1.5), Color(0.39, 0.53, 0.74), 1.4, 3.7, 34)
	_lived_in_details()
	# Очень слабый отражённый свет: пол и маршрут различимы между световыми островками.
	var bounce := OmniLight3D.new()
	bounce.name = "HallBounce"
	bounce.position = Vector3(-0.3, 1.25, 0.9)
	bounce.light_color = Color(0.56, 0.62, 0.72)
	bounce.light_energy = 0.28
	bounce.omni_range = 3.6
	bounce.shadow_enabled = true
	add_child(bounce)
	# Боковое заполнение показывает мебель/ящики, которые не ловят свет сверху.
	for data in [["LeftSeatingFill", Vector3(-3.55, 1.6, 0), 0.85, 4.3, Color(0.78, 0.80, 0.78)], ["StoreFill", Vector3(4.0, 1.65, -2.4), 0.7, 2.5, Color(0.76, 0.82, 0.77)], ["ServicePassageFill", Vector3(2.2, 1.5, 0.2), 0.55, 2.6, Color(0.78, 0.80, 0.76)]]:
		var fill := OmniLight3D.new()
		fill.name = data[0]
		fill.position = data[1]
		fill.light_energy = data[2]
		fill.omni_range = data[3]
		fill.light_color = data[4]
		fill.shadow_enabled = true
		add_child(fill)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.04, 0.045, 0.05)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.43, 0.49, 0.58)
	environment.environment.ambient_light_energy = 0.30
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


func wall_z(label: String, z: float, a: float, b: float, doorway: float = 99, width: float = 0.9, door: bool = false) -> void:
	if doorway == 99:
		box(label, Vector3((a+b)/2, 1.4, z), Vector3(b-a, 2.8, 0.14), plaster)
	else:
		wall_z(label + "L", z, a, doorway-width/2)
		wall_z(label + "R", z, doorway+width/2, b)
		box(label + "Lintel", Vector3(doorway, 2.45, z), Vector3(width, 0.7, 0.14), wood)
		if door:
			# Полотно в открытом положении лежит вдоль стены, не торчит в зал.
			var into_room := -1.0 if label == "KitchenFront" else 1.0
			box(label + "OpenDoor", Vector3(doorway-width/2-0.04, 1.03, z+into_room*width/2), Vector3(0.045, 2.06, width), wood)
			box(label + "Handle", Vector3(doorway-width/2-0.005, 1.0, z+into_room*(width-0.12)), Vector3(0.06, 0.025, 0.12), brass, false)


func wall_x(label: String, x: float, a: float, b: float, doorway: float = 99, width: float = 0.9, door: bool = false) -> void:
	if doorway == 99:
		box(label, Vector3(x, 1.4, (a+b)/2), Vector3(0.14, 2.8, b-a), plaster)
	else:
		wall_x(label + "L", x, a, doorway-width/2)
		wall_x(label + "R", x, doorway+width/2, b)
		box(label + "Lintel", Vector3(x, 2.45, doorway), Vector3(0.14, 0.7, width), wood)
		if door:
			box(label + "OpenDoor", Vector3(x+width/2, 1.03, doorway-width/2-0.04), Vector3(width, 2.06, 0.045), wood)
			box(label + "Handle", Vector3(x+width-0.12, 1.0, doorway-width/2), Vector3(0.12, 0.025, 0.06), brass, false)


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
	cylinder("StoolRim", pos + Vector3.UP * 0.72, 0.22, 0.065, wood)
	cylinder("StoolSeat", pos + Vector3.UP * 0.77, 0.205, 0.07, leather)
	for x in [-0.145, 0.145]:
		for z in [-0.145, 0.145]:
			box("StoolLeg", pos + Vector3(x, 0.35, z), Vector3(0.055, 0.70, 0.055), wood)
		box("StoolRung", pos + Vector3(x, 0.26, 0), Vector3(0.035, 0.035, 0.32), brass, false)
		box("StoolRung", pos + Vector3(0, 0.26, x), Vector3(0.32, 0.035, 0.035), wood, false)
	# Сиденье тоже твёрдое, открытый каркас не заменяется массивным кубом.
	box("StoolSeatSupport", pos + Vector3.UP * 0.70, Vector3(0.33, 0.05, 0.33), wood)


func chair(pos: Vector3, yaw: float) -> void:
	var start := geometry.get_child_count()
	box("ChairSeat", Vector3(0, 0.43, 0), Vector3(0.46, 0.065, 0.45), wood)
	box("ChairCushion", Vector3(0, 0.48, -0.01), Vector3(0.41, 0.06, 0.39), leather, false)
	for x in [-0.19, 0.19]:
		box("ChairFrontLeg", Vector3(x, 0.21, -0.17), Vector3(0.055, 0.42, 0.055), wood)
		box("ChairBackPost", Vector3(x, 0.49, 0.18), Vector3(0.055, 0.98, 0.055), wood)
		box("ChairBrace", Vector3(x, 0.22, 0), Vector3(0.035, 0.04, 0.38), wood, false)
	box("ChairBackRail", Vector3(0, 0.94, 0.18), Vector3(0.43, 0.09, 0.065), wood)
	box("ChairBackCushion", Vector3(0, 0.77, 0.17), Vector3(0.33, 0.23, 0.065), leather, false)
	for i in range(start, geometry.get_child_count()):
		var part := geometry.get_child(i) as Node3D
		part.position = pos + part.position.rotated(Vector3.UP, yaw)
		part.rotation.y = yaw


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


func lamp(pos: Vector3, energy: float, reach: float, color: Color = Color(1.0, 0.82, 0.59)) -> SpotLight3D:
	cylinder("LampShade", pos, 0.18, 0.14, brass)
	cylinder("LampCable", Vector3(pos.x, 2.7, pos.z), 0.009, 0.4, dark)
	if energy > 0:
		var bulb := StandardMaterial3D.new()
		bulb.albedo_color = color
		bulb.emission_enabled = true
		bulb.emission = color * 0.7
		cylinder("LampBulb", pos-Vector3.UP*0.073, 0.115, 0.012, bulb)
	return spot("PendantLight", pos - Vector3.UP * 0.10, pos - Vector3.UP, color, energy, reach, 58)


func spot(label: String, pos: Vector3, target: Vector3, color: Color, energy: float, reach: float, angle: float) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = label
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.spot_range = reach
	light.spot_angle = angle
	light.spot_attenuation = 0.8
	light.shadow_enabled = true
	light.shadow_bias = 0.035
	add_child(light, true)
	light.look_at(target, Vector3.FORWARD if absf((target-pos).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)
	return light


func _process(delta: float) -> void:
	_light_time += delta
	# Только одна дальняя лампа: мягкое проседание на 12%, раз в ~23 с.
	var phase := fposmod(_light_time, 23.7)
	_flicker.light_energy = 1.35 * (1.0 - 0.12 * pow(sin((phase - 20.0) / 0.7 * PI), 2)) if phase > 20.0 and phase < 20.7 else 1.35


func _lived_in_details() -> void:
	var paper := material(Color(0.34, 0.32, 0.25), 0)
	box("FoldedPaper", Vector3(-3.55, 0.838, -0.48), Vector3(0.22, 0.008, 0.16), paper, false).rotation.y = 0.23
	box("LeftBook", Vector3(-2.95, 0.85, 3.25), Vector3(0.22, 0.04, 0.16), leather, false).rotation.y = -0.18
	box("ForgottenCoaster", Vector3(0.95, 1.163, -1.35), Vector3(0.14, 0.005, 0.14), paper, false)
	for pos in [Vector3(-3.25, 0.834, -2.7), Vector3(-3.6, 0.834, 1.55), Vector3(0.65, 1.162, -1.2)]:
		var mark := MeshInstance3D.new()
		mark.name = "GlassRing"
		var ring := TorusMesh.new()
		ring.inner_radius = 0.045
		ring.outer_radius = 0.049
		ring.rings = 24
		ring.ring_segments = 6
		mark.mesh = ring
		mark.scale.y = 0.12
		mark.position = pos
		mark.material_override = material(Color(0.085, 0.075, 0.06), 0)
		geometry.add_child(mark, true)
	for pos in [Vector3(-1.5, 0.77, -0.35), Vector3(0.55, 0.77, -0.35), Vector3(-4.4, 0.583, 1.5)]:
		box("SeatScuff", pos + Vector3(0, 0.037, 0), Vector3(0.12, 0.002, 0.045), material(Color(0.21, 0.18, 0.145), 3), false).rotation.y = 0.35
	# Собственные условные выцветшие снимки зданий, без новых сюжетных фактов.
	for z in [-1.45, 1.35]:
		box("FadedPhoto", Vector3(-4.786, 1.8, z), Vector3(0.008, 0.39, 0.27), paper, false)
		for i in 4:
			box("PhotoSilhouette", Vector3(-4.779, 1.70 + (i%2)*0.025, z-0.09+i*0.06), Vector3(0.006, 0.13+(i%2)*0.05, 0.04), dark, false)
