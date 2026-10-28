class_name VisitorModel
extends Node3D
## CHAR-01: собственный TEST-макет. +Z — лицо, ноги y=-1.65, центр головы y=0.
## Жёсткие сегменты на Skeleton3D; это не готовый персонаж с мягкой деформацией.

var skeleton: Skeleton3D
var talking: bool = false
var _time: float = 0.0
var _bones: Dictionary = {}
var _skin: StandardMaterial3D
var _cloth: StandardMaterial3D
var _dark: StandardMaterial3D
var _hair: StandardMaterial3D


func _ready() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	_skin = _material(Color(0.52, 0.40, 0.30))
	_cloth = _fabric(Color(0.25, 0.31, 0.29))
	_dark = _fabric(Color(0.11, 0.12, 0.14))
	_hair = _material(Color(0.075, 0.057, 0.046))
	_bone("Pelvis", "", Vector3(0, -0.87, 0))
	_bone("Chest", "Pelvis", Vector3(0, 0.40, 0))
	_bone("Head", "Chest", Vector3(0, 0.47, 0))
	var torso := _attachment("Chest")
	_rings(torso, "Jacket", [Vector4(-0.38, 0.19, 0.12, 0), Vector4(-0.22, 0.20, 0.13, 0), Vector4(0.02, 0.23, 0.135, 0), Vector4(0.18, 0.225, 0.12, 0), Vector4(0.23, 0.13, 0.09, 0)], _cloth, 12)
	_box(torso, "Undershirt", Vector3(0, 0.13, 0.118), Vector3(0.16, 0.21, 0.026), _dark)
	for side in [-1, 1]:
		var suffix := "L" if side < 0 else "R"
		_bone("UpperArm" + suffix, "Chest", Vector3(side * 0.225, 0.13, 0))
		_bone("Forearm" + suffix, "UpperArm" + suffix, Vector3(side * 0.055, -0.27, 0.045))
		_bone("Hand" + suffix, "Forearm" + suffix, Vector3(-side * 0.025, -0.24, 0.115))
		var arm := _attachment("UpperArm" + suffix)
		var shoulder := MeshInstance3D.new()
		var cap := SphereMesh.new()
		cap.radius = 0.085
		cap.height = 0.17
		cap.radial_segments = 8
		cap.rings = 4
		shoulder.mesh = cap
		shoulder.material_override = _cloth
		arm.add_child(shoulder)
		_tube(arm, "Sleeve", Vector3.ZERO, Vector3(side * 0.055, -0.28, 0.045), 0.09, 0.070, _cloth)
		var forearm := _attachment("Forearm" + suffix)
		_tube(forearm, "Sleeve", Vector3.ZERO, Vector3(-side * 0.025, -0.24, 0.115), 0.073, 0.057, _cloth)
		_tube(forearm, "Cuff", Vector3(-side * 0.023, -0.22, 0.105), Vector3(-side * 0.025, -0.245, 0.118), 0.059, 0.058, _dark)
		var hand := _attachment("Hand" + suffix)
		_tube(hand, "Palm", Vector3.ZERO, Vector3(0, -0.075, 0.025), 0.043, 0.039, _skin)
		for finger in 4:
			var x := (finger - 1.5) * 0.018
			_tube(hand, "Finger%d" % finger, Vector3(x, -0.065, 0.035), Vector3(x, -0.12 + absf(finger - 1.5) * 0.012, 0.055), 0.010, 0.008, _skin, 5)
		_tube(hand, "Thumb", Vector3(side * 0.038, -0.012, 0.015), Vector3(side * 0.053, -0.064, 0.043), 0.016, 0.011, _skin, 6)
		_bone("Thigh" + suffix, "Pelvis", Vector3(side * 0.107, 0, 0))
		_bone("Shin" + suffix, "Thigh" + suffix, Vector3(side * 0.018, -0.35, 0.028))
		_bone("Foot" + suffix, "Shin" + suffix, Vector3(0, -0.34, -0.01))
		_tube(_attachment("Thigh" + suffix), "Trouser", Vector3(0, 0.07, 0), Vector3(side * 0.018, -0.36, 0.028), 0.115, 0.083, _dark)
		_tube(_attachment("Shin" + suffix), "Trouser", Vector3.ZERO, Vector3(0, -0.34, -0.01), 0.083, 0.065, _dark)
		var foot := _attachment("Foot" + suffix)
		var shoe := Node3D.new()
		shoe.position.z = 0.05
		foot.add_child(shoe)
		_rings(shoe, "Shoe", [Vector4(-0.09, 0.07, 0.15, 0), Vector4(-0.065, 0.075, 0.15, 0), Vector4(-0.015, 0.067, 0.13, 0), Vector4(0.025, 0.052, 0.08, 0)], _hair, 10)
		var pocket := _box(torso, "Pocket" + suffix, Vector3(side * 0.136, 0.015, 0.128), Vector3(0.103, 0.12, 0.018), _cloth)
		pocket.rotation.z = side * 0.035
		var collar := _box(torso, "Collar" + suffix, Vector3(side * 0.065, 0.183, 0.12), Vector3(0.068, 0.15, 0.025), _cloth)
		collar.rotation.z = side * 0.48
		for button in 4:
			_box(torso, "Button%s%d" % [suffix, button], Vector3(side * 0.022, 0.06 - button * 0.11, 0.141), Vector3(0.009, 0.009, 0.005), _hair)
	_tube(_attachment("Head"), "Neck", Vector3(0, -0.26, 0), Vector3(0, -0.10, 0), 0.065, 0.067, _skin)
	var head_shape := Node3D.new()
	head_shape.name = "HeadShape"
	head_shape.scale = Vector3.ONE * 0.85
	head_shape.position.y = -0.07
	_attachment("Head").add_child(head_shape)
	_build_head(head_shape)
	skeleton.reset_bone_poses()


func _bone(label: String, parent: String, offset: Vector3) -> void:
	var index := skeleton.get_bone_count()
	skeleton.add_bone(label)
	_bones[label] = index
	if not parent.is_empty():
		skeleton.set_bone_parent(index, _bones[parent])
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, offset))


func _attachment(label: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = label + "Parts"
	attachment.bone_name = label
	skeleton.add_child(attachment)
	return attachment


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material


func _fabric(color: Color) -> StandardMaterial3D:
	# Собственная кодовая фактура ткани; воспроизводима без сторонних изображений.
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var grain := float((x * 17 + y * 31 + x * y * 7) % 19) / 19.0
			var fold := pow(absf(sin(x * 0.17 + sin(y * 0.045) * 2.0)), 12.0)
			image.set_pixel(x, y, Color.WHITE * (0.76 + grain * 0.16 - fold * 0.16))
	var material := _material(color)
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material


func _box(parent: Node3D, label: String, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.material_override = material
	part.position = center
	parent.add_child(part)
	return part


func _tube(parent: Node3D, label: String, start: Vector3, end: Vector3, radius_a: float, radius_b: float, material: Material, segments: int = 8) -> void:
	var length := start.distance_to(end)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_a
	mesh.bottom_radius = radius_b
	mesh.height = length
	mesh.radial_segments = segments
	mesh.rings = 2
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.material_override = material
	part.position = (start + end) * 0.5
	part.quaternion = Quaternion(Vector3.UP, (start - end).normalized())
	parent.add_child(part)


func _rings(parent: Node3D, label: String, rings: Array, material: Material, segments: int) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rings.size() - 1:
		for column in segments:
			for corner in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var ring: Vector4 = rings[row + corner.y]
				var angle: float = TAU * (column + corner.x) / float(segments)
				tool.set_uv(Vector2((column + corner.x) / float(segments), (row + corner.y) / float(rings.size() - 1)))
				tool.add_vertex(Vector3(sin(angle) * ring.y, ring.x, cos(angle) * ring.z))
	tool.generate_normals()
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = tool.commit()
	part.material_override = material
	parent.add_child(part)


func _build_head(parent: Node3D) -> void:
	# Фронтальная проекция только на переднюю половину; затылок не повторяет лицо.
	var face := _material(Color.WHITE)
	face.albedo_texture = load("res://assets/characters/test_visitor/face.png")
	face.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	face.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# y, ширина, глубина: подбородок -> темя.
	var rings := [Vector3(-0.145, 0.060, 0.065), Vector3(-0.10, 0.095, 0.085), Vector3(-0.045, 0.115, 0.097), Vector3(0.015, 0.126, 0.105), Vector3(0.080, 0.123, 0.103), Vector3(0.145, 0.109, 0.091), Vector3(0.205, 0.060, 0.055), Vector3(0.22, 0.004, 0.004)]
	var texture_widths := [0.10, 0.235, 0.275, 0.30, 0.335, 0.345, 0.23, 0.04]
	for row in rings.size() - 1:
		for column in 16:
			for corner in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var ring: Vector3 = rings[row + corner.y]
				var angle: float = -PI / 2 + PI * (column + corner.x) / 16.0
				var x := sin(angle) * ring.y
				var z := cos(angle) * ring.z
				# Объём переносицы/носа, губ и надбровья — в самой геометрии.
				z += exp(-pow(x / 0.025, 2)) * exp(-pow((ring.x + 0.025) / 0.042, 2)) * 0.043
				z += exp(-pow(x / 0.05, 2)) * exp(-pow((ring.x + 0.085) / 0.018, 2)) * 0.009
				tool.set_uv(Vector2(0.5 + sin(angle) * texture_widths[row + corner.y], 0.05 + (0.22 - ring.x) / 0.365 * 0.89))
				tool.add_vertex(Vector3(x, ring.x, z))
	tool.generate_normals()
	var front := MeshInstance3D.new()
	front.name = "Face"
	front.mesh = tool.commit()
	front.material_override = face
	parent.add_child(front)
	# Задняя половина головы, уши и отдельный объём волос.
	var skull := SphereMesh.new()
	skull.radius = 0.125
	skull.height = 0.345
	skull.radial_segments = 16
	skull.rings = 8
	var back := MeshInstance3D.new()
	back.name = "Skull"
	back.mesh = skull
	back.material_override = _skin
	back.position = Vector3(0, 0.035, -0.036)
	back.scale.z = 0.79
	parent.add_child(back)
	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var ear_mesh := SphereMesh.new()
		ear_mesh.radius = 0.025
		ear_mesh.height = 0.062
		ear_mesh.radial_segments = 8
		ear_mesh.rings = 4
		ear.mesh = ear_mesh
		ear.material_override = _skin
		ear.position = Vector3(side * 0.123, 0.008, -0.012)
		ear.scale.x = 0.55
		parent.add_child(ear)
	# Отдельный затылок с волосами: лоб и лицо не дублируются сзади.
	var rear_hair := MeshInstance3D.new()
	var rear_mesh := SphereMesh.new()
	rear_mesh.radius = 0.127
	rear_mesh.height = 0.25
	rear_mesh.radial_segments = 14
	rear_mesh.rings = 6
	rear_hair.mesh = rear_mesh
	rear_hair.material_override = _hair
	rear_hair.position = Vector3(0, 0.085, -0.055)
	rear_hair.scale.z = 0.70
	parent.add_child(rear_hair)
	_rings(parent, "Hair", [Vector4(0.105, 0.121, 0.075, 0), Vector4(0.175, 0.110, 0.065, 0), Vector4(0.224, 0.069, 0.040, 0), Vector4(0.24, 0.001, 0.001, 0)], _hair, 14)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	skeleton.set_bone_pose_rotation(_bones.Chest, Quaternion.from_euler(Vector3(sin(_time * 1.3) * 0.008, 0, 0)))
	skeleton.set_bone_pose_rotation(_bones.Head, Quaternion.from_euler(Vector3(sin(_time * 0.8) * 0.012, sin(_time * 0.37) * 0.055, 0.012)))
	var gesture := sin(_time * 1.7) * 0.10 if talking else sin(_time * 0.7) * 0.015
	skeleton.set_bone_pose_rotation(_bones.ForearmR, Quaternion.from_euler(Vector3(-gesture, 0, -gesture * 0.4)))
	skeleton.set_bone_pose_rotation(_bones.HandR, Quaternion.from_euler(Vector3(0, gesture * 0.5, 0)))
