extends Node3D
## Небольшой TEST-дом. Размеры в метрах, план и бытовые состояния локальны.

const ACTION_TARGET = preload("res://scripts/home/targets/house_action_target.gd")
var home: Node3D
var actions: Dictionary = {}
var switches: Dictionary = {}
var kettle_remaining: float = 0.0
var tea_ready: bool = false
var radio_on: bool = false
var radio: AudioStreamPlayer3D
var _materials: Dictionary = {}
var _steam: MeshInstance3D


func _material(id: String, color: Color, metal: float = 0.0) -> StandardMaterial3D:
	if _materials.has(id):
		return _materials[id]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.86 if metal == 0 else 0.3
	result.metallic = metal
	_materials[id] = result
	return result


func _box(id: String, center: Vector3, size: Vector3, material: Material, solid: bool = true, parent: Node3D = null) -> MeshInstance3D:
	if parent == null:
		parent = self
	var node := MeshInstance3D.new()
	node.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	node.position = center
	if solid:
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		node.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
	return node


func _round(id: String, center: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = id
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	node.position = center
	return node


func _bind(id: String, parts: Array, caption: Callable, action: Callable) -> void:
	var target := ACTION_TARGET.new()
	target.name = id + "Action"
	target.collision_layer = 0
	target.collision_mask = 0
	target.monitoring = false
	target.caption = caption
	target.action = func() -> void:
		home.feedback_target = target
		action.call()
		home.feedback_target = null
	var primary: Node3D = parts[0]
	target.context_anchor = primary
	target.allowed = func() -> bool: return home.house_actions_allowed() and home.rig.view.global_position.distance_to(primary.global_position) <= 2.5
	add_child(target)
	for part: Node3D in parts:
		# Регистрация нужна и в release, где assert полностью вырезается.
		var registered: bool = home.interaction.register_surface(part.get_node("Body"), target)
		if not registered:
			push_error("House surface missing: " + str(part.get_path()))
	actions[id] = target


func _inspect(id: String, parts: Array, title: String, text: String) -> void:
	_bind(id, parts, func() -> String: return "осмотреть: " + title, func() -> void: home.show_house_inspection(title, text))
	actions[id].context_title = title
	actions[id].context_description = text.replace(" J — открыть дневник.", "")
	actions[id].context_passive = true
	var primary: Node3D = parts[0]
	actions[id].allowed = func() -> bool: return home.house_information_allowed() and home.rig.view.global_position.distance_to(primary.global_position) <= 2.5


func _light(id: String, position: Vector3, color: Color, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = id
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 6
	light.omni_attenuation = 1.5
	light.shadow_enabled = true
	add_child(light)
	light.position = position
	return light


func _switch(id: String, position: Vector3, lights: Array) -> void:
	var plate := _box(id, position, Vector3(0.12, 0.19, 0.07), _materials.ivory)
	_box(id + "Key", position + Vector3(0, 0, -0.045), Vector3(0.065, 0.1, 0.03), _materials.metal, false)
	switches[id] = true
	_bind(id, [plate], func() -> String: return "выключить свет" if switches[id] else "включить свет", func() -> void:
		switches[id] = not switches[id]
		for light: Light3D in lights:
			light.visible = switches[id]
		home.house_feedback("Свет включён" if switches[id] else "Свет выключен")
	)


func _cabinet(id: String, position: Vector3, size: Vector3, material: Material, interior: String) -> void:
	_box(id + "Back", position - Vector3(0, 0, size.z * 0.45), Vector3(size.x, size.y, 0.08), material)
	for direction in [-1, 1]:
		_box(id + "Side" + str(direction), position + Vector3(direction * (size.x - 0.08) / 2, 0, 0), Vector3(0.08, size.y, size.z), material)
	for level in [-0.5, 0.0, 0.5]:
		_box(id + "Shelf" + str(level), position + Vector3(0, level * (size.y - 0.08), 0), Vector3(size.x, 0.08, size.z), material)
	var pivot := Node3D.new()
	pivot.name = id + "Hinge"
	add_child(pivot)
	pivot.position = position + Vector3(-size.x / 2, 0, size.z / 2 + 0.045)
	var door := _box(id + "Door", Vector3(size.x / 2, 0, 0), Vector3(size.x, size.y, 0.08), material, true, pivot)
	_box("Handle", Vector3(size.x - 0.1, 0, 0.065), Vector3(0.035, 0.23, 0.04), _materials.metal, false, pivot)
	var inside := _box(id + "Contents", position + Vector3(0, -size.y / 4, 0), Vector3(size.x * 0.55, size.y * 0.23, size.z * 0.55), _materials.cloth, false)
	switches[id] = false
	_bind(id, [door], func() -> String: return ("закрыть " if switches[id] else "открыть ") + interior, func() -> void:
		switches[id] = not switches[id]
		pivot.rotation.y = deg_to_rad(-105) if switches[id] else 0
		home.house_feedback("Открыто: " + interior if switches[id] else "Закрыто")
	)
	inside.visible = true


func _seat(id: String, parts: Array, eye: Vector3, yaw: float, title: String) -> void:
	var anchor := AnchorPoint.new()
	anchor.name = id + "Seat"
	anchor.anchor_id = StringName("seat_" + id.to_lower())
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	anchor.display_name = title
	# AnchorPoint ожидает Marker/Label даже у невидимого технического места.
	var marker := Node3D.new()
	marker.name = "Marker"
	var label := Label3D.new()
	label.name = "Label"
	marker.add_child(label)
	anchor.add_child(marker)
	home.get_node("Anchors").add_child(anchor)
	anchor.position = eye
	anchor.rotation_degrees.y = yaw
	anchor.neighbours = PackedStringArray(["home_entry"])
	_bind(id, parts, func() -> String: return "сесть: " + title, func() -> void:
		if home.rig.can_move_to(anchor.anchor_id):
			home.rig.request_move(anchor.anchor_id)
		else:
			home.house_feedback("Подойдите к сиденью ближе")
	)


func _sliding_door(id: String, closed: Vector3, opened: Vector3, size: Vector3, title: String) -> void:
	var door := _box(id, opened, size, _materials.wood)
	var handle := _box(id + "Handle", closed + Vector3(0.15, 0.05, size.z / 2 + 0.12), Vector3(0.14, 0.24, 0.12), _materials.metal)
	var back_handle := _box(id + "BackHandle", closed + Vector3(-0.15, 0.05, size.z / 2 + 0.12), Vector3(0.14, 0.24, 0.12), _materials.metal)
	switches[id] = false
	_bind(id, [door, handle, back_handle], func() -> String: return ("открыть " if switches[id] else "закрыть ") + title, func() -> void:
		if not switches[id]:
			var shape := BoxShape3D.new()
			shape.size = size
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform.origin = to_global(closed)
			query.collision_mask = 4
			if not get_world_3d().direct_space_state.intersect_shape(query).is_empty():
				home.house_feedback("Отойдите от дверного проёма")
				return
		switches[id] = not switches[id]
		door.position = closed if switches[id] else opened
		home.house_feedback("Дверь закрыта" if switches[id] else "Дверь открыта")
	)


func build(owner_home: Node3D) -> void:
	home = owner_home
	_material("plaster", Color(0.31, 0.32, 0.29))
	_material("wood", Color(0.23, 0.17, 0.12))
	_material("trim", Color(0.13, 0.14, 0.13))
	_material("floor", Color(0.25, 0.22, 0.18))
	_material("ivory", Color(0.65, 0.62, 0.51))
	_material("cloth", Color(0.24, 0.29, 0.26))
	_material("metal", Color(0.35, 0.36, 0.34), 0.7)
	_material("glass", Color(0.12, 0.21, 0.26), 0.45)
	_material("tile", Color(0.36, 0.4, 0.37))
	_material("water", Color(0.22, 0.42, 0.46), 0.4)
	# Четыре прежних предмета и их имена остаются контрактами DA-062.
	for id in ["Floor", "BackWall", "FrontWall", "LeftWall", "RightWall", "Ceiling"]:
		var old: MeshInstance3D = home.get_node("Geometry/" + id)
		old.hide()
		old.get_node("Body").collision_layer = 0
	_box("Floor", Vector3(-0.7, -0.12, -0.7), Vector3(8.6, 0.24, 7.6), _materials.floor)
	_box("Ceiling", Vector3(-0.7, 3.02, -0.7), Vector3(8.8, 0.16, 7.8), _materials.plaster)
	# Наружные стены; спальня сохраняет существующее окно у x=3.43.
	_box("NorthWall", Vector3(-0.7, 1.5, -4.6), Vector3(8.8, 3, 0.2), _materials.plaster)
	_box("SouthWall", Vector3(-0.7, 1.5, 3.2), Vector3(8.8, 3, 0.2), _materials.plaster)
	_box("WestWall", Vector3(-5.1, 1.5, -0.7), Vector3(0.2, 3, 7.6), _materials.plaster)
	_box("EastWall", Vector3(3.7, 1.5, -0.7), Vector3(0.2, 3, 7.6), _materials.plaster)
	# Два прохода спальни: из гостиной и из прихожей, ширина 1.6 м.
	for spec in [[-3.375, 2.25], [0.0, 1.3], [2.675, 0.85]]:
		_box("BedroomPartition" + str(spec[0]), Vector3(0, 1.5, spec[0]), Vector3(0.16, 3, spec[1]), _materials.plaster)
	for z in [-1.45, 1.45]:
		_box("BedroomLintel" + str(z), Vector3(0, 2.7, z), Vector3(0.18, 0.6, 1.6), _materials.trim)
	# Прихожая отделена от гостиной; широкий проём вдоль пути от входа.
	_box("LivingPartitionWest", Vector3(-3.875, 1.5, 0.6), Vector3(2.25, 3, 0.16), _materials.plaster)
	_box("LivingPartitionEast", Vector3(-0.525, 1.5, 0.6), Vector3(1.05, 3, 0.16), _materials.plaster)
	_box("LivingLintel", Vector3(-1.9, 2.7, 0.6), Vector3(1.7, 0.6, 0.18), _materials.trim)
	# Санузел в левом углу прихожей: вход шириной 1.1 м с востока.
	_box("BathPartitionNorth", Vector3(-3.2, 1.5, 0.85), Vector3(0.16, 3, 0.5), _materials.plaster)
	_box("BathPartitionSouth", Vector3(-3.2, 1.5, 2.65), Vector3(0.16, 3, 0.9), _materials.plaster)
	_box("BathLintel", Vector3(-3.2, 2.7, 1.65), Vector3(0.18, 0.6, 1.1), _materials.trim)
	_box("BathTiles", Vector3(-4.1, 0.009, 1.85), Vector3(1.8, 0.015, 2.5), _materials.tile, false)
	for index in 27:
		_box("FloorSeam" + str(index), Vector3(-4.95 + index * 0.32, 0.006, -0.7), Vector3(0.012, 0.012, 7.6), _materials.trim, false)
	for x in [-5.0, 3.58]:
		_box("Skirting" + str(x), Vector3(x, 0.08, -0.7), Vector3(0.04, 0.16, 7.6), _materials.trim, false)
	_box("EntranceMat", Vector3(-1.8, 0.018, 2.45), Vector3(1.15, 0.025, 0.8), _materials.cloth, false)
	_box("BedroomRug", Vector3(1.5, 0.018, -0.3), Vector3(2.3, 0.025, 1.2), _materials.cloth, false)
	home.get_node("CeilingLight").light_energy = 0.55
	home.get_node("CeilingLight").position = Vector3(-2.2, 2.7, -1.4)
	var hall_light := _light("HallLight", Vector3(-1.6, 2.65, 1.8), Color(1, 0.8, 0.56), 0.8)
	var living_light := _light("LivingLight", Vector3(-2.4, 2.65, -2.9), Color(1, 0.84, 0.65), 0.9)
	var bed_light := _light("BedroomLight", Vector3(1.8, 2.6, 0), Color(0.8, 0.86, 1), 0.65)
	var bath_light := _light("BathLight", Vector3(-4.1, 2.6, 1.8), Color(0.83, 0.92, 0.86), 0.8)
	for point in [Vector3(-1.6, 2.82, 1.8), Vector3(-2.4, 2.82, -2.9), Vector3(1.8, 2.82, 0), Vector3(-4.1, 2.82, 1.8)]:
		_box("CeilingShade" + str(point.x), point, Vector3(0.5, 0.1, 0.5), _materials.ivory, false)
	_switch("HallSwitch", Vector3(-1.0, 1.3, 3.04), [hall_light])
	_switch("LivingSwitch", Vector3(-0.6, 1.3, 0.48), [living_light, home.get_node("CeilingLight")])
	_switch("BedroomSwitch", Vector3(0.7, 1.3, 3.04), [bed_light])
	_switch("BathSwitch", Vector3(-3.29, 1.3, 2.5), [bath_light])
	_build_entry()
	_build_living()
	_build_bedroom()
	_build_bath()


func _build_entry() -> void:
	var shelf := _box("KeyTable", Vector3(-2.65, 0.65, 2.7), Vector3(0.55, 1.3, 0.55), _materials.wood)
	_box("KeyTray", Vector3(-2.65, 1.32, 2.7), Vector3(0.3, 0.035, 0.2), _materials.metal, false)
	_round("Keys", Vector3(-2.65, 1.35, 2.7), 0.065, 0.012, _materials.metal)
	_inspect("Keys", [shelf], "Ключи", "Связка ключей лежит в металлическом подносе у входа.")
	var hanger := _box("CoatRack", Vector3(-0.7, 1.9, 2.96), Vector3(0.65, 0.12, 0.12), _materials.wood)
	_box("Coat", Vector3(-0.7, 1.38, 2.87), Vector3(0.47, 0.85, 0.12), _materials.cloth, false)
	_inspect("Coat", [hanger], "Вешалка", "Тёмная куртка висит на деревянной вешалке.")
	# Ширма закрывает прямой взгляд в санузел, не сужая проход к двери.
	_box("BathFrame", Vector3(-3.26, 1.2, 2.18), Vector3(0.08, 2.4, 0.08), _materials.trim)
	_sliding_door("BathroomDoor", Vector3(-3.2, 1.2, 1.65), Vector3(-3.2, 1.2, 2.79), Vector3(0.09, 2.4, 1.08), "дверь санузла")


func _build_living() -> void:
	# Кухонный ряд вдоль задней стены, стол для осмотра остаётся на своём месте.
	_box("KitchenBase", Vector3(-3.25, 0.46, -4.02), Vector3(2.4, 0.92, 0.85), _materials.cloth)
	var counter := _box("KitchenCounter", Vector3(-3.25, 0.96, -4.02), Vector3(2.5, 0.1, 0.9), _materials.ivory)
	_box("KitchenBacksplash", Vector3(-3.25, 1.3, -4.47), Vector3(2.5, 0.6, 0.035), _materials.tile, false)
	var kettle := _box("Kettle", Vector3(-2.8, 1.18, -3.93), Vector3(0.34, 0.35, 0.3), _materials.metal)
	var kettle_mesh := CylinderMesh.new()
	kettle_mesh.top_radius = 0.12
	kettle_mesh.bottom_radius = 0.17
	kettle_mesh.height = 0.35
	kettle_mesh.radial_segments = 12
	kettle.mesh = kettle_mesh
	_box("KettleSpout", Vector3(-3.0, 1.25, -3.93), Vector3(0.16, 0.09, 0.1), _materials.metal, false)
	_box("KettleHandle", Vector3(-2.57, 1.21, -3.93), Vector3(0.1, 0.25, 0.2), _materials.trim, false)
	_round("Mug", Vector3(-3.35, 1.14, -3.88), 0.085, 0.22, _materials.ivory)
	_steam = _box("KettleSteam", Vector3(-2.8, 1.48, -3.93), Vector3(0.05, 0.22, 0.05), _materials.ivory, false)
	_steam.hide()
	_bind("Kettle", [kettle, counter], func() -> String:
		return "выпить чай" if tea_ready else ("выключить чайник" if kettle_remaining > 0 else "поставить чайник")
	, func() -> void:
		if tea_ready:
			tea_ready = false
			home.house_feedback("Вы выпили чай. Можно продолжать исследование.")
		elif kettle_remaining > 0:
			kettle_remaining = 0
			home.house_feedback("Чайник выключен")
		else:
			kettle_remaining = 6
			home.house_feedback("Чайник греется…")
	)
	_cabinet("Fridge", Vector3(-1.1, 0.95, -4.02), Vector3(0.75, 1.9, 0.8), _materials.ivory, "холодильник")
	_box("SofaBase", Vector3(-4.35, 0.36, -0.35), Vector3(1.05, 0.6, 1.55), _materials.wood)
	var sofa := _box("SofaCushion", Vector3(-4.3, 0.72, -0.35), Vector3(0.9, 0.2, 1.4), _materials.cloth)
	_box("SofaBack", Vector3(-4.76, 1.0, -0.35), Vector3(0.16, 0.85, 1.65), _materials.cloth)
	_seat("Sofa", [sofa], Vector3(-4.1, 1.25, -0.35), -90, "Диван")
	var dining := _box("DiningTop", Vector3(-4.0, 0.82, -2.6), Vector3(1.2, 0.12, 0.9), _materials.wood)
	_box("DiningPedestal", Vector3(-4, 0.4, -2.6), Vector3(0.3, 0.8, 0.3), _materials.wood)
	_inspect("DiningTable", [dining], "Кухонный стол", "Небольшой деревянный стол. На нём оставлена пустая тарелка.")
	var chair := _box("DiningChair", Vector3(-4, 0.48, -1.65), Vector3(0.55, 0.12, 0.55), _materials.wood)
	for x in [-4.21, -3.79]:
		for z in [-1.86, -1.44]:
			_box("ChairLeg" + str(x) + str(z), Vector3(x, 0.22, z), Vector3(0.065, 0.44, 0.065), _materials.wood, false)
	_box("DiningChairBack", Vector3(-4, 0.85, -1.38), Vector3(0.55, 0.75, 0.08), _materials.wood)
	_seat("DiningChair", [chair], Vector3(-4, 1.2, -1.65), 0, "Стул у стола")
	_round("Plate", Vector3(-4.1, 0.9, -2.6), 0.16, 0.025, _materials.ivory)
	var radio_body := _box("Radio", Vector3(-4.5, 1.03, 0.23), Vector3(0.45, 0.25, 0.2), _materials.wood)
	_box("RadioStand", Vector3(-4.5, 0.42, 0.23), Vector3(0.65, 0.84, 0.4), _materials.wood)
	_box("RadioDial", Vector3(-4.5, 1.05, 0.115), Vector3(0.3, 0.1, 0.018), _materials.ivory, false)
	radio = AudioStreamPlayer3D.new()
	radio.name = "RadioSound"
	radio.stream = _radio_stream()
	radio.max_distance = 7
	add_child(radio)
	radio.position = radio_body.position
	_bind("Radio", [radio_body], func() -> String: return "выключить радио" if radio_on else "включить радио", func() -> void:
		radio_on = not radio_on
		home.house_feedback("Радио включено" if radio_on else "Радио выключено")
	)
	var pane := _box("LivingWindow", Vector3(-4.97, 1.85, -2.6), Vector3(0.06, 1.5, 1.65), _materials.glass)
	_inspect("LivingWindow", [pane], "Окно гостиной", "За стеклом темно. У окна можно постоять и прислушаться к дому.")
	_curtain("LivingCurtain", Vector3(-4.82, 1.85, -3.52), Vector3(0.08, 1.65, 0.16), Vector3(0.08, 1.65, 1.85))


func _curtain(id: String, center: Vector3, open_size: Vector3, closed_size: Vector3) -> void:
	var cloth := _box(id, center, open_size, _materials.cloth)
	switches[id] = false
	_bind(id, [cloth], func() -> String: return "раздвинуть штору" if switches[id] else "задвинуть штору", func() -> void:
		switches[id] = not switches[id]
		var size := closed_size if switches[id] else open_size
		(cloth.mesh as BoxMesh).size = size
		(cloth.get_node("Body").get_child(0).shape as BoxShape3D).size = size
		cloth.position.z = center.z + (closed_size.z - open_size.z) / 2 if switches[id] else center.z
		home.house_feedback("Штора закрыта" if switches[id] else "Штора открыта")
	)


func _build_bedroom() -> void:
	_cabinet("Wardrobe", Vector3(2.9, 1.05, -3.95), Vector3(1.15, 2.1, 0.85), _materials.wood, "шкаф")
	var desk := _box("BedroomDesk", Vector3(1.15, 0.82, -4.0), Vector3(1.25, 0.12, 0.85), _materials.wood)
	_box("BedroomDeskBase", Vector3(1.15, 0.4, -4.0), Vector3(0.85, 0.8, 0.6), _materials.wood)
	_inspect("BedroomDesk", [desk], "Письменный стол", "Небольшой письменный стол под лампой. J — открыть дневник.")
	var lamp := _box("DeskLamp", Vector3(0.8, 1.15, -3.9), Vector3(0.22, 0.5, 0.22), _materials.ivory)
	var light := _light("DeskLampLight", Vector3(0.8, 1.42, -3.8), Color(1, 0.8, 0.53), 0.4)
	switches["DeskLamp"] = true
	_bind("DeskLamp", [lamp], func() -> String: return "выключить настольную лампу" if switches.DeskLamp else "включить настольную лампу", func() -> void:
		switches.DeskLamp = not switches.DeskLamp
		light.visible = switches.DeskLamp
	)
	var clock := _box("Clock", Vector3(3.12, 1.0, 0.35), Vector3(0.24, 0.18, 0.1), _materials.trim)
	_box("BedsideTable", Vector3(3.12, 0.43, 0.35), Vector3(0.55, 0.86, 0.5), _materials.wood)
	_inspect("Clock", [clock], "Часы", "На циферблате 00:00.")
	_box("BedHeadboard", Vector3(2.15, 0.9, 0.1), Vector3(1.65, 1.25, 0.12), _materials.wood)
	_curtain("BedroomCurtain", Vector3(3.22, 1.9, -2.45), Vector3(0.08, 1.9, 0.16), Vector3(0.08, 1.9, 2.05))
	_sliding_door("BedroomDoor", Vector3(-0.04, 1.2, 1.45), Vector3(-0.04, 1.2, 2.79), Vector3(0.1, 2.4, 1.55), "дверь спальни")


func _build_bath() -> void:
	var sink := _box("Sink", Vector3(-4.22, 0.86, 0.93), Vector3(0.8, 0.18, 0.5), _materials.ivory)
	_box("SinkBasin", Vector3(-4.22, 0.958, 0.96), Vector3(0.6, 0.014, 0.31), _materials.metal, false)
	_box("SinkPedestal", Vector3(-4.22, 0.4, 0.93), Vector3(0.32, 0.8, 0.32), _materials.ivory)
	_box("Tap", Vector3(-4.22, 1.1, 0.8), Vector3(0.05, 0.28, 0.1), _materials.metal, false)
	var water := _box("TapWater", Vector3(-4.22, 0.98, 0.98), Vector3(0.025, 0.18, 0.025), _materials.water, false)
	water.hide()
	switches.Sink = false
	_bind("Sink", [sink], func() -> String: return "закрыть кран" if switches.Sink else "умыться и открыть воду", func() -> void:
		switches.Sink = not switches.Sink
		water.visible = switches.Sink
		home.house_feedback("Вы умылись. Вода течёт." if switches.Sink else "Кран закрыт")
	)
	var mirror := _box("Mirror", Vector3(-4.22, 1.7, 0.72), Vector3(0.8, 0.8, 0.045), _materials.metal)
	_inspect("Mirror", [mirror], "Зеркало", "Потемневшее стекло в узкой раме над раковиной.")
	_cabinet("BathroomCabinet", Vector3(-3.55, 2.2, 0.9), Vector3(0.5, 0.65, 0.3), _materials.ivory, "шкафчик")
	var shower := _box("ShowerTray", Vector3(-4.5, 0.08, 2.5), Vector3(0.85, 0.16, 0.9), _materials.ivory)
	_box("ShowerPipe", Vector3(-4.92, 1.3, 2.6), Vector3(0.045, 1.8, 0.045), _materials.metal, false)
	_box("ShowerHead", Vector3(-4.78, 2.15, 2.6), Vector3(0.3, 0.06, 0.2), _materials.metal, false)
	_inspect("Shower", [shower], "Душ", "Небольшой поддон, металлическая труба и душевая лейка.")
	var toilet := _box("Toilet", Vector3(-3.65, 0.35, 2.45), Vector3(0.48, 0.5, 0.65), _materials.ivory)
	_box("ToiletTank", Vector3(-3.65, 0.65, 2.88), Vector3(0.55, 0.85, 0.2), _materials.ivory)
	_round("ToiletSeat", Vector3(-3.65, 0.61, 2.4), 0.22, 0.035, _materials.ivory)
	_inspect("Toilet", [toilet], "Санузел", "Тесный угол за дверью. Рядом раковина и душевой поддон.")


func room_at(point: Vector3) -> String:
	if point.x < -3.2 and point.z > 0.6:
		return "Санузел"
	if point.x >= 0:
		return "Спальня"
	return "Прихожая" if point.z > 0.6 else "Кухня-гостиная"


func tick(delta: float, active: bool, gain: float) -> void:
	if kettle_remaining > 0 and active:
		kettle_remaining = maxf(0, kettle_remaining - delta)
		if kettle_remaining == 0:
			tea_ready = true
			if home.interaction.get_target() == actions.Kettle:
				actions.Kettle.context_feedback = "Чай готов"
			home.house_feedback("Чай готов. Подойдите к чайнику, чтобы выпить.")
	_steam.visible = kettle_remaining > 0
	if radio_on and active and gain > 0:
		radio.volume_db = linear_to_db(maxf(0.0001, gain * 0.08))
		if not radio.playing:
			radio.play()
	else:
		radio.stop()


func _radio_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 44100
	var data := PackedByteArray()
	data.resize((stream.loop_end + 1) * 2)
	for index in stream.loop_end + 1:
		var phase := TAU * float(index % stream.loop_end) / 22050.0
		var value := 0.3 * sin(phase * 174) + 0.12 * sin(phase * 261) + 0.08 * sin(phase * 348)
		data.encode_s16(index * 2, roundi(value * 32767))
	stream.data = data
	return stream


func _exit_tree() -> void:
	if is_instance_valid(radio):
		radio.stop()
