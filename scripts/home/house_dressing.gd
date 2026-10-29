extends Node3D
## HOME-03: только визуальный слой поверх HOME-02. Коллизии/координаты исходника не меняются.

const SURFACE = preload("res://assets/shaders/house_surface.gdshader")
var house: Node3D
var home: Node3D
var mats: Dictionary = {}
var curtains: Array[Dictionary] = []

func _mat(id: String, tint: Color, kind: int, roughness: float = 0.75) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("roughness_value", roughness)
	var surface := ""
	if id in ["wood", "floor"]: surface = "wood"
	if id == "plaster": surface = "plaster"
	if id in ["cloth", "linen", "rug"]: surface = "fabric"
	preload("res://scripts/presentation/environment_textures.gd").apply(m, surface)
	mats[id] = m
	return m

func build(source: Node3D) -> void:
	house = source
	home = source.home
	_mat("plaster", Color("8a887c"), 0, 0.95)
	_mat("wood", Color("76604a"), 1, 0.64)
	_mat("trim", Color("494f4b"), 0, 0.65)
	_mat("floor", Color("6f5b47"), 2, 0.73)
	_mat("ivory", Color("c4c0ad"), 7, 0.3)
	_mat("cloth", Color("667365"), 3, 0.94)
	_mat("metal", Color("8b8b80"), 6, 0.38)
	_mat("glass", Color("344e62"), 8, 0.24)
	_mat("tile", Color("91a19b"), 4, 0.36)
	_mat("stone", Color("9e9b8b"), 5, 0.52)
	_mat("linen", Color("b7ad91"), 3, 0.98)
	_mat("leather", Color("635440"), 3, 0.67)
	_mat("brass", Color("a08b60"), 6, 0.46)
	_mat("paper", Color("c7bda1"), 0, 0.98)
	_mat("dark", Color("242b29"), 0, 0.84)
	_mat("rug", Color("6e5146"), 3, 0.99)
	_mat("paint", Color("717e77"), 0, 0.72)
	_replace_surfaces()
	_architecture()
	_kitchen()
	_living()
	_bedroom()
	_bathroom()
	_entry()
	_lighting()
	for id in ["LivingCurtain", "BedroomCurtain"]:
		var original: MeshInstance3D = house.get_node(id)
		original.hide()
		var cloth := MeshInstance3D.new()
		cloth.name = id + "Fabric"
		cloth.material_override = mats.linen
		add_child(cloth)
		curtains.append({"source": original, "visual": cloth, "size": Vector3.ZERO})
	_update_curtains()

func _replace_surfaces() -> void:
	for node in house.find_children("*", "MeshInstance3D", true, false):
		for id in house._materials:
			if node.material_override == house._materials[id] and mats.has(id):
				node.material_override = mats[id]
				break
		var id := str(node.name)
		if node.mesh is CylinderMesh:
			node.mesh = node.mesh.duplicate()
			node.mesh.radial_segments = 32
		if id.begins_with("FloorSeam") or id.begins_with("CeilingShade"):
			node.hide()
		if node.mesh is BoxMesh and not ("Wall" in id or "Partition" in id or "Lintel" in id or "Curtain" in id or id in ["Floor", "Ceiling", "TapWater", "KettleSteam"]):
			var size: Vector3 = node.mesh.size
			var radius := minf(size[size.min_axis_index()] * 0.18, 0.018)
			if id in ["SofaCushion", "SofaBack", "Coat"]:
				radius = minf(size[size.min_axis_index()] * 0.42, 0.065)
			node.mesh = _soft_box(size, radius)
	for node in home.get_node("Geometry").get_children():
		if not node is MeshInstance3D or not node.visible:
			continue
		var id := str(node.name)
		node.material_override = mats.wood
		if id == "Mattress": node.material_override = mats.cloth
		if id == "Pillow": node.material_override = mats.linen
		if id == "Book": node.material_override = mats.paper
		if id == "Window": node.material_override = mats.glass
		if id == "WindowBar": node.material_override = mats.ivory
		# Сохраняем единичный AABB и исходный transform блоков старой сцены.
		if node.mesh is BoxMesh:
			node.mesh = _soft_box(node.mesh.size, 0.43 if id == "Pillow" else 0.025)
	house.get_node("KitchenBase").material_override = mats.paint
	house.get_node("KitchenCounter").material_override = mats.stone
	house.get_node("BedroomRug").material_override = mats.rug

func _soft_box(size: Vector3, radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var inner := half - Vector3.ONE * radius
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var us := [-half[u], -inner[u], inner[u], half[u]]
			var vs := [-half[v], -inner[v], inner[v], half[v]]
			for a in 3:
				for b in 3:
					var corners: Array[Vector3] = []
					for pair in [Vector2i(a,b), Vector2i(a+1,b), Vector2i(a+1,b+1), Vector2i(a,b+1)]:
						var point := Vector3.ZERO
						point[axis] = half[axis] * sign_value
						point[u] = us[pair.x]
						point[v] = vs[pair.y]
						corners.append(point)
					# Godot использует clockwise лицевые треугольники.
					var indices := [0, 2, 1, 0, 3, 2] if sign_value > 0 else [0, 1, 2, 0, 2, 3]
					for index in indices:
						var point := corners[index]
						var core := point.clamp(-inner, inner)
						var normal := (point - core).normalized()
						st.set_normal(normal)
						st.set_uv(Vector2(point[u], point[v]))
						st.add_vertex(core + normal * radius)
	st.index()
	return st.commit()

func _box(id: String, p: Vector3, size: Vector3, material: Material, parent: Node3D = null, radius: float = 0.008) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = _soft_box(size, minf(radius, size[size.min_axis_index()] * 0.35))
	node.material_override = material
	(parent if parent != null else self).add_child(node)
	node.position = p
	return node

func _cylinder(id: String, p: Vector3, radius: float, height: float, mat: Material, top: float = -1.0, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 32
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = mesh
	node.material_override = mat
	(parent if parent != null else self).add_child(node)
	node.position = p
	return node

func _ring(id: String, p: Vector3, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = id
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 8
	node.mesh = mesh
	node.material_override = mat
	add_child(node)
	node.position = p
	return node

func _architecture() -> void:
	# Плинтусы и потолочный карниз повторяют каждый существующий отрезок стены.
	for node in house.get_children():
		if not node is MeshInstance3D or not node.mesh is BoxMesh:
			continue
		var id := str(node.name)
		if not ("Wall" in id or "Partition" in id): continue
		var size: Vector3 = node.mesh.size
		for y in [0.10, 2.87]:
			var trim_size := Vector3(size.x + 0.035, 0.13 if y < 1 else 0.075, size.z + 0.035)
			_box(id + "Moulding" + str(y), Vector3(node.position.x, y, node.position.z), trim_size, mats.trim if y < 1 else mats.ivory)
	# Обрамления в исходных проёмах; ширина ходьбы сохранена, без новых тел.
	for z in [-1.45, 1.45]:
		for edge in [-0.8, 0.8]:
			_box("BedroomArchitrave", Vector3(0, 1.19, z + edge), Vector3(0.22, 2.38, 0.045), mats.wood)
	for x in [-2.75, -1.05]:
		_box("LivingArchitrave", Vector3(x, 1.2, 0.6), Vector3(0.045, 2.4, 0.22), mats.wood)
	for z in [1.1, 2.2]:
		_box("BathArchitrave", Vector3(-3.2, 1.2, z), Vector3(0.22, 2.4, 0.045), mats.wood)
	_window("Living", Vector3(-4.92, 1.85, -2.6), Vector2(1.65, 1.5), 1)
	_window("Bedroom", Vector3(3.34, 1.9, -1.4), Vector2(2, 1.8), -1)
	# Отделка движется вместе с исходными дверями, не образует новых интерактивных целей.
	for id in ["BathroomDoor", "BedroomDoor"]:
		var door: Node3D = house.get_node(id)
		for side in [-1, 1]:
			_box(id + "Inset", Vector3(side * 0.053, 0.05, 0), Vector3(0.012, 1.95, 0.78 if id == "BathroomDoor" else 1.20), mats.paint, door)
	for id in ["Wardrobe", "BathroomCabinet", "Fridge"]:
		var pivot: Node3D = house.get_node(id + "Hinge")
		var door: MeshInstance3D = pivot.get_node(id + "Door")
		var aabb := door.mesh.get_aabb()
		var s := aabb.size
		_box(id + "FrontInset", door.position + Vector3(0, 0, 0.047), Vector3(s.x - 0.12, s.y - 0.14, 0.018), mats.paint if id == "BathroomCabinet" else (mats.ivory if id == "Fridge" else mats.wood), pivot)

func _window(id: String, p: Vector3, size: Vector2, side: int) -> void:
	for z in [-size.x / 2, size.x / 2]:
		_box(id + "WindowJamb", p + Vector3(0, 0, z), Vector3(0.10, size.y + 0.14, 0.065), mats.ivory)
	for y in [-size.y / 2, size.y / 2]:
		_box(id + "WindowRail", p + Vector3(0, y, 0), Vector3(0.10, 0.065, size.x + 0.14), mats.ivory)
	_box(id + "WindowCross", p, Vector3(0.095, 0.035, size.x), mats.trim)
	_box(id + "WindowMullion", p, Vector3(0.095, size.y, 0.035), mats.trim)
	_box(id + "Sill", p + Vector3(side * 0.055, -size.y/2 - 0.07, 0), Vector3(0.28, 0.07, size.x + 0.23), mats.stone)
	var rod := _cylinder(id + "CurtainRail", p + Vector3(side * 0.13, size.y/2 + 0.09, 0), 0.015, size.x + 0.3, mats.brass)
	rod.rotation.x = PI / 2
	# Радиатор под окном, вне существующего прохода.
	for i in 12:
		_box(id + "RadiatorFin", Vector3(p.x + side * 0.07, 0.58, p.z - 0.55 + i * 0.10), Vector3(0.12, 0.52, 0.07), mats.ivory, null, 0.02)

func _kitchen() -> void:
	for x in [-4.05, -3.25, -2.45]:
		_box("KitchenDoor", Vector3(x, 0.49, -3.582), Vector3(0.77, 0.75, 0.025), mats.paint)
		_box("KitchenInset", Vector3(x, 0.46, -3.562), Vector3(0.63, 0.54, 0.014), mats.cloth)
		_box("KitchenPull", Vector3(x, 0.78, -3.535), Vector3(0.22, 0.025, 0.025), mats.brass)
	_box("KitchenToeKick", Vector3(-3.25, 0.09, -3.57), Vector3(2.35, 0.11, 0.025), mats.dark)
	_box("KitchenShelf", Vector3(-3.25, 1.98, -4.32), Vector3(2.45, 0.055, 0.31), mats.wood)
	for x in [-4.1, -2.4]:
		_box("ShelfBracket", Vector3(x, 1.87, -4.39), Vector3(0.026, 0.23, 0.20), mats.brass)
	for i in 5:
		var x := -4.14 + i * 0.19
		_cylinder("PantryJar", Vector3(x, 2.13, -4.30), 0.068, 0.24, mats.ivory if i % 2 == 0 else mats.cloth)
		_cylinder("JarLid", Vector3(x, 2.257, -4.30), 0.071, 0.025, mats.wood)
		_box("JarLabel", Vector3(x, 2.13, -4.23), Vector3(0.085, 0.07, 0.008), mats.paper)
	for i in 3:
		_cylinder("StackedDish", Vector3(-2.55, 2.024 + i * 0.022, -4.29), 0.12, 0.018, mats.ivory)
	# Чайник и кружка остаются ровно на исходных местах.
	_cylinder("KettleLid", Vector3(-2.8, 1.36, -3.93), 0.122, 0.026, mats.metal)
	_cylinder("KettleKnob", Vector3(-2.8, 1.385, -3.93), 0.035, 0.035, mats.dark)
	_cylinder("MugTea", Vector3(-3.35, 1.252, -3.88), 0.070, 0.003, mats.dark)
	var handle := _ring("MugHandle", Vector3(-3.245, 1.15, -3.88), 0.040, 0.057, mats.ivory)
	handle.rotation.x = PI/2
	_box("CuttingBoard", Vector3(-3.95, 1.021, -3.95), Vector3(0.46, 0.023, 0.30), mats.wood)
	_box("TeaTowel", Vector3(-3.92, 1.039, -3.91), Vector3(0.23, 0.012, 0.24), mats.linen)
	for i in 4:
		_box("TowelStripe", Vector3(-4.0 + i * 0.048, 1.047, -3.91), Vector3(0.009, 0.003, 0.23), mats.cloth)
	_box("OutletPlate", Vector3(-2.25, 1.42, -4.443), Vector3(0.12, 0.15, 0.015), mats.ivory)
	for x in [-2.27, -2.23]:
		_cylinder("OutletPin", Vector3(x, 1.42, -4.43), 0.008, 0.005, mats.dark).rotation.x = PI/2

func _living() -> void:
	# Каркас/подушки не сдвигаются; добавлены кант, подлокотники, швы и плед.
	for z in [-1.11, 0.41]:
		_box("SofaArm", Vector3(-4.30, 0.83, z), Vector3(0.94, 0.20, 0.09), mats.cloth, null, 0.035)
	_box("SofaSeatSeam", Vector3(-4.3, 0.823, -0.35), Vector3(0.78, 0.005, 0.008), mats.trim)
	_box("SofaPiping", Vector3(-3.848, 0.77, -0.35), Vector3(0.009, 0.009, 1.32), mats.linen)
	_box("FoldedThrow", Vector3(-4.25, 0.848, -0.73), Vector3(0.66, 0.055, 0.38), mats.linen, null, 0.02)
	for i in 6:
		_box("ThrowFringe", Vector3(-3.91, 0.83, -0.88 + i * 0.06), Vector3(0.055, 0.009, 0.014), mats.linen)
	for i in 6:
		_box("RadioGrille", Vector3(-4.65 + i * 0.035, 1.05, 0.12), Vector3(0.012, 0.16, 0.014), mats.dark)
	_cylinder("RadioKnob", Vector3(-4.34, 1.0, 0.115), 0.022, 0.022, mats.brass).rotation.x = PI/2
	var antenna := _cylinder("RadioAntenna", Vector3(-4.68, 1.32, 0.25), 0.004, 0.40, mats.metal)
	antenna.rotation.z = -0.15
	# Ненарративные отпечатки: абстрактный пейзаж, без новых имён/сюжетных улик.
	_picture("LivingPrint", Vector3(-4.955, 1.85, -0.3), Vector2(0.78, 0.61), PI/2)
	for i in 2:
		_ring("TableCupRing", Vector3(-2.65 + i * 0.15, 0.878, -1.82), 0.062, 0.065, mats.wood).scale.y = 0.18
	_box("BookCover", Vector3(-2.2, 0.958, -1.9), Vector3(0.49, 0.008, 0.35), mats.leather)
	_box("Bookmark", Vector3(-2.08, 0.963, -1.74), Vector3(0.025, 0.003, 0.10), mats.rug)
	_box("ChairSeatPad", Vector3(-4, 0.555, -1.65), Vector3(0.48, 0.035, 0.47), mats.leather, null, 0.015)
	for x in [-4.20, -3.80]:
		_box("ChairBrace", Vector3(x, 0.23, -1.65), Vector3(0.035, 0.04, 0.40), mats.wood)

func _picture(id: String, p: Vector3, size: Vector2, yaw: float) -> void:
	var root := Node3D.new()
	root.name = id
	add_child(root)
	root.position = p
	root.rotation.y = yaw
	_box("Frame", Vector3.ZERO, Vector3(size.x, size.y, 0.035), mats.wood, root)
	_box("Mat", Vector3(0,0,0.023), Vector3(size.x-0.055, size.y-0.055, 0.012), mats.paper, root)
	_box("DistantSky", Vector3(0,0,0.031), Vector3(size.x-0.13, size.y-0.13, 0.005), mats.paint, root)
	_box("Horizon", Vector3(0,-size.y*0.18,0.035), Vector3(size.x-0.13, size.y*0.23, 0.004), mats.trim, root)
	for i in 7:
		_box("Landscape", Vector3(-size.x*0.32 + i*size.x*0.10, -size.y*0.09, 0.038), Vector3(size.x*0.06, size.y*(0.08+0.025*(i%3)), 0.003), mats.wood, root)

func _bedroom() -> void:
	# Мягкий верх одеяла внутри прежней площади кровати.
	var blanket := MeshInstance3D.new()
	blanket.name = "Duvet"
	blanket.material_override = mats.linen
	add_child(blanket)
	blanket.mesh = _fabric_grid(32, 28, func(u: float, v: float) -> Vector3:
		var edge := pow(absf(u * 2.0 - 1.0), 12)
		var fold := sin(u * 41.0 + v * 3.5) * 0.007 + sin(u * 19.0 - v * 7.0) * 0.005
		return Vector3(1.405 + u*1.49, 0.724 + fold - edge * 0.085, 0.99 + v*1.53)
	)
	_box("DuvetTurnover", Vector3(2.15, 0.75, 1.06), Vector3(1.47, 0.028, 0.22), mats.ivory, null, 0.01)
	var throw := MeshInstance3D.new()
	throw.name = "BedThrow"
	throw.material_override = mats.rug
	add_child(throw)
	throw.mesh = _fabric_grid(32, 10, func(u: float, v: float) -> Vector3:
		return Vector3(1.405 + u*1.49, 0.75 + sin(u*30.0+v*2.0)*0.008 - pow(absf(u*2.0-1.0), 10)*0.10, 1.92+v*0.40)
	)
	_box("HeadboardInset", Vector3(2.15, 0.98, 0.17), Vector3(1.43, 0.82, 0.026), mats.cloth, null, 0.012)
	for i in 6:
		_box("HeadboardStitch", Vector3(1.55 + i*0.24, 0.98, 0.188), Vector3(0.006, 0.75, 0.004), mats.trim)
	_box("NightstandDrawer", Vector3(3.12, 0.60, 0.609), Vector3(0.47, 0.22, 0.025), mats.wood)
	_box("NightstandPull", Vector3(3.12, 0.60, 0.633), Vector3(0.11, 0.018, 0.018), mats.brass)
	_box("ClockFace", Vector3(3.12, 1, 0.405), Vector3(0.195, 0.13, 0.009), mats.paper)
	for i in [-1, 1]:
		_box("ClockHands", Vector3(3.12 + i*0.025, 1, 0.412), Vector3(0.008, 0.067, 0.005), mats.dark)
	_box("DeskBlotter", Vector3(1.25, 0.889, -3.9), Vector3(0.67, 0.013, 0.45), mats.leather)
	for i in 3:
		_box("DeskPaper", Vector3(1.25+i*0.006, 0.902+i*0.003, -3.92), Vector3(0.28, 0.002, 0.35), mats.paper).rotation.y = 0.06*i
	var pen := _cylinder("Pencil", Vector3(1.5, 0.905, -3.86), 0.005, 0.18, mats.wood)
	pen.rotation.x = PI/2
	pen.rotation.z = 0.25
	house.get_node("DeskLamp").hide()
	_cylinder("DeskLampFoot", Vector3(0.8, 0.91, -3.9), 0.108, 0.05, mats.brass)
	_cylinder("DeskLampStem", Vector3(0.8, 1.1, -3.9), 0.015, 0.36, mats.brass)
	_cylinder("DeskLampShade", Vector3(0.8, 1.31, -3.9), 0.16, 0.18, mats.cloth, 0.09)
	_picture("BedroomPrint", Vector3(1.3, 1.95, -4.48), Vector2(0.65, 0.48), 0)
	# Полосы ковра и кромка — ткань, без новых коллизий.
	for z in [-0.81, 0.21]:
		_box("RugBorder", Vector3(1.5, 0.033, z), Vector3(2.12, 0.004, 0.045), mats.linen)

func _bathroom() -> void:
	house.get_node("Sink").hide()
	house.get_node("SinkBasin").hide()
	var basin := MeshInstance3D.new()
	basin.name = "CeramicBasin"
	basin.material_override = mats.ivory
	add_child(basin)
	var profile := [Vector3(0.29, 0.79, 0.15), Vector3(0.39, 0.90, 0.24), Vector3(0.40, 0.948, 0.25), Vector3(0.31, 0.951, 0.175), Vector3(0.25, 0.89, 0.13), Vector3(0.06, 0.85, 0.045)]
	basin.mesh = _fabric_grid(48, profile.size()-1, func(u: float, v: float) -> Vector3:
		var index := mini(roundi(v*(profile.size()-1)), profile.size()-1)
		var ring: Vector3 = profile[index]
		# Скруглённый прямоугольник, не плоская пластина исходного graybox.
		var x := cos(u*TAU)
		var z := sin(u*TAU)
		return Vector3(-4.22 + signf(x)*pow(absf(x),0.65)*ring.x, ring.y, 0.96 + signf(z)*pow(absf(z),0.65)*ring.z)
	)
	_cylinder("BasinDrain", Vector3(-4.22, 0.851, 0.96), 0.055, 0.006, mats.metal)
	_box("BathroomWainscotWest", Vector3(-4.993, 0.73, 1.85), Vector3(0.015, 1.4, 2.48), mats.tile)
	_box("BathroomWainscotNorth", Vector3(-4.12, 0.73, 0.692), Vector3(1.72, 1.4, 0.018), mats.tile)
	_box("BathroomWainscotSouth", Vector3(-4.12, 0.73, 3.092), Vector3(1.72, 1.4, 0.018), mats.tile)
	for x in [-4.65, -3.79]:
		_box("MirrorFrame", Vector3(x, 1.7, 0.751), Vector3(0.035, 0.85, 0.035), mats.brass)
	for y in [1.285, 2.115]:
		_box("MirrorFrame", Vector3(-4.22, y, 0.751), Vector3(0.89, 0.035, 0.035), mats.brass)
	_box("MirrorShelf", Vector3(-4.22, 1.22, 0.82), Vector3(0.88, 0.035, 0.22), mats.stone)
	_cylinder("SoapBottle", Vector3(-4.51, 1.00, 1.01), 0.046, 0.16, mats.cloth)
	_box("SoapPump", Vector3(-4.51, 1.09, 1.01), Vector3(0.08, 0.025, 0.025), mats.brass)
	_cylinder("ToothbrushCup", Vector3(-3.94, 1.34, 0.83), 0.047, 0.19, mats.ivory)
	_cylinder("Brush", Vector3(-3.94, 1.47, 0.83), 0.008, 0.2, mats.wood)
	_box("TowelRail", Vector3(-4.91, 1.32, 1.75), Vector3(0.06, 0.025, 0.56), mats.brass)
	_box("BathTowel", Vector3(-4.875, 1.06, 1.75), Vector3(0.035, 0.54, 0.40), mats.linen, null, 0.01)
	for i in 4:
		_box("TowelHem", Vector3(-4.853, 0.83+i*0.016, 1.75), Vector3(0.006, 0.006, 0.38), mats.cloth)
	# Более читаемая чаша вместо визуального куба; прежний collider/цель сохранены.
	house.get_node("Toilet").hide()
	_cylinder("ToiletPedestalVisual", Vector3(-3.65, 0.30, 2.45), 0.17, 0.42, mats.ivory, 0.21)
	var bowl := _cylinder("ToiletBowlVisual", Vector3(-3.65, 0.48, 2.43), 0.17, 0.22, mats.ivory, 0.23)
	bowl.scale.z = 1.24
	_cylinder("ToiletOpening", Vector3(-3.65, 0.632, 2.4), 0.165, 0.003, mats.dark).scale.z = 1.12
	_ring("ToiletRim", Vector3(-3.65, 0.635, 2.4), 0.167, 0.218, mats.ivory).scale = Vector3(1, 0.35, 1.14)
	_box("FlushButton", Vector3(-3.65, 1.079, 2.88), Vector3(0.09, 0.012, 0.055), mats.metal)
	_box("ShowerDrain", Vector3(-4.5, 0.164, 2.5), Vector3(0.11, 0.007, 0.11), mats.metal)
	for i in 4:
		_box("DrainSlot", Vector3(-4.54+i*0.026, 0.169, 2.5), Vector3(0.008, 0.003, 0.085), mats.dark)

func _entry() -> void:
	for y in [0.6, 1.65]:
		_box("EntranceDoorPanel", Vector3(-1.8, y, 2.872), Vector3(0.86, 0.79, 0.018), mats.paint)
	_box("DoorLockPlate", Vector3(-1.39, 1.15, 2.854), Vector3(0.052, 0.20, 0.018), mats.brass)
	_box("DoorLever", Vector3(-1.45, 1.18, 2.824), Vector3(0.16, 0.025, 0.035), mats.brass)
	for x in [-2.38, -1.22]:
		_box("EntryDoorFrame", Vector3(x, 1.2, 2.94), Vector3(0.055, 2.4, 0.18), mats.ivory)
	_box("EntryDoorLintel", Vector3(-1.8, 2.39, 2.94), Vector3(1.2, 0.065, 0.18), mats.ivory)
	for i in 3:
		_box("CoatHook", Vector3(-0.92+i*0.22, 1.87, 2.84), Vector3(0.018, 0.085, 0.085), mats.brass)
	_box("CoatPlacket", Vector3(-0.7, 1.38, 2.801), Vector3(0.018, 0.77, 0.012), mats.trim)
	for y in [1.15, 1.35, 1.55]:
		_cylinder("CoatButton", Vector3(-0.68, y, 2.789), 0.012, 0.007, mats.brass).rotation.x = PI/2
	_box("KeyTableFront", Vector3(-2.65, 0.98, 2.416), Vector3(0.46, 0.29, 0.02), mats.wood)
	_box("KeyTablePull", Vector3(-2.65, 0.98, 2.396), Vector3(0.12, 0.018, 0.02), mats.brass)
	_ring("KeyRing", Vector3(-2.65, 1.363, 2.7), 0.034, 0.040, mats.brass)
	for i in 3:
		_box("KeyBlade", Vector3(-2.62+i*0.025, 1.365, 2.66), Vector3(0.012, 0.006, 0.08), mats.brass).rotation.y = i*0.3
	_picture("HallPrint", Vector3(-0.50, 1.95, 3.075), Vector2(0.56, 0.43), PI)

func _lighting() -> void:
	# Собственная Environment камеры не меняет свет бара и пользовательскую постобработку.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101923")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a5b5c5")
	environment.ambient_light_energy = 0.28
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	home.rig.view.environment = environment
	var levels := {"HallLight": [0.8, 3.6], "LivingLight": [0.85, 4.4], "BedroomLight": [0.58, 3.8], "BathLight": [0.78, 2.9], "DeskLampLight": [0.55, 1.85]}
	for id in levels:
		var light: OmniLight3D = house.get_node(id)
		light.light_energy = levels[id][0]
		light.omni_range = levels[id][1]
		light.omni_attenuation = 1.0
		light.light_color = Color("ffe2b7") if id != "BathLight" else Color("d9e7df")
		light.shadow_bias = 0.025
		light.light_specular = 0.25
		if id == "DeskLampLight":
			# Источник под абажуром: не проецирует огромную тень собственного плафона.
			light.light_energy = 0.0
			var desk_task := _spot("DeskTask", Vector3(0.8,1.21,-3.9), Vector3(1.15,0.82,-3.75), Color("ffe2b7"), 1.0, 1.6, 62)
			desk_task.reparent(light)
		if id != "DeskLampLight":
			var p := Vector3(light.position.x, 2.82, light.position.z)
			_cylinder(id + "Mount", p + Vector3(0,0.095,0), 0.09, 0.05, mats.brass)
			_cylinder(id + "Shade", p, 0.28 if id == "LivingLight" else 0.22, 0.14, mats.cloth, 0.19)
			var diffuser := StandardMaterial3D.new()
			diffuser.albedo_color = Color("e3d1ab")
			diffuser.emission_enabled = true
			diffuser.emission = Color("efd4a4")
			diffuser.emission_energy_multiplier = 0.8
			var bulb := _cylinder(id + "Diffuser", p + Vector3(0,-0.076,0), 0.195, 0.012, diffuser)
			# Материал отдельный для лампы; следует прежнему выключателю.
			light.visibility_changed.connect(func(): (bulb.material_override as StandardMaterial3D).emission_enabled = light.visible)
	home.get_node("CeilingLight").light_energy = 0.30
	home.get_node("CeilingLight").light_specular = 0.2
	home.get_node("CeilingLight").omni_range = 4.0
	var window: OmniLight3D = home.get_node("WindowLight")
	window.light_energy = 0.4
	window.light_specular = 0.15
	window.omni_range = 3.7
	window.shadow_enabled = true
	_spot("WestWindowWash", Vector3(-4.75,2.15,-2.6), Vector3(-2.2,0,-1.5), Color("9db8d8"), 0.9, 4.6, 48)
	_spot("EastWindowWash", Vector3(3.19,2.2,-1.4), Vector3(0.4,0,-0.1), Color("9db8d8"), 0.85, 4.5, 45)
	var kitchen := _spot("KitchenTask", Vector3(-3.25,1.93,-4.24), Vector3(-3.25,0.96,-3.98), Color("ffe7c2"), 1.1, 1.6, 62)
	house.get_node("LivingLight").visibility_changed.connect(func(): kitchen.visible = house.get_node("LivingLight").visible)

func _spot(id: String, p: Vector3, target: Vector3, color: Color, energy: float, reach: float, angle: float) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = id
	add_child(light)
	light.position = p
	light.look_at(to_global(target))
	light.light_color = color
	light.light_energy = energy
	light.light_specular = 0.25
	light.spot_range = reach
	light.spot_angle = angle
	light.spot_attenuation = 0.8
	light.shadow_enabled = true
	light.shadow_bias = 0.02
	return light

func _process(_delta: float) -> void:
	_update_curtains()

func _update_curtains() -> void:
	for curtain in curtains:
		var source: MeshInstance3D = curtain.source
		var visual: MeshInstance3D = curtain.visual
		var size: Vector3 = source.mesh.size
		visual.transform = source.transform
		if size.is_equal_approx(curtain.size): continue
		curtain.size = size
		var folds := 5 if size.z < 0.3 else 12
		visual.mesh = _fabric_grid(48, 12, func(u: float, v: float) -> Vector3:
			return Vector3(sin(u*TAU*folds)*size.x*0.42, size.y*(0.5-v) + sin(u*TAU*folds)*0.012*v*v, size.z*(u-0.5))
		)

func _fabric_grid(columns: int, rows: int, point: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1, -1]:
		st.set_smooth_group(0 if side == 1 else 1)
		for y in rows:
			for x in columns:
				var coords := [Vector2(x,y), Vector2(x+1,y), Vector2(x+1,y+1), Vector2(x,y+1)]
				for index in ([0,1,2,0,2,3] if side == 1 else [0,2,1,0,3,2]):
					var uv: Vector2 = coords[index] / Vector2(columns, rows)
					st.set_uv(uv)
					st.add_vertex(point.call(uv.x, uv.y))
	st.generate_normals()
	st.index()
	return st.commit()
