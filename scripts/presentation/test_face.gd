class_name TestFace
extends Node3D
## Нейтральные TEST-морфологии; это не персонажи и не сюжетные идентификаторы.

const PROFILES := {
	&"test_face_a": {"width": 0.145, "height": 0.48, "depth": 0.14, "jaw": 0.70, "chin": 0.44, "nose": 0.095, "nose_width": 0.028, "eye_gap": 0.065, "brow": 0.20, "mouth": 0.064, "asymmetry": 0.004},
	&"test_face_b": {"width": 0.190, "height": 0.42, "depth": 0.145, "jaw": 0.96, "chin": 0.70, "nose": 0.055, "nose_width": 0.045, "eye_gap": 0.082, "brow": -0.15, "mouth": 0.093, "asymmetry": -0.005},
	&"test_face_c": {"width": 0.170, "height": 0.45, "depth": 0.14, "jaw": 0.66, "chin": 0.34, "nose": 0.075, "nose_width": 0.032, "eye_gap": 0.074, "brow": 0.33, "mouth": 0.076, "asymmetry": 0.013}
}
const RINGS := [Vector3(-0.50, 0.4, 0.62), Vector3(-0.34, 0.8, 0.85), Vector3(-0.13, 0.89, 0.97), Vector3(0.10, 1.0, 1.0), Vector3(0.32, 0.94, 0.93), Vector3(0.49, 0.78, 0.82), Vector3(0.58, 0.12, 0.30)]

var _appearance_id: StringName = &"test_face_a"
var _parts: Node3D
var _skin: StandardMaterial3D
var _shade: StandardMaterial3D
var _hair: StandardMaterial3D


static func get_appearance_ids() -> Array[StringName]:
	return [&"test_face_a", &"test_face_b", &"test_face_c"]


func _ready() -> void:
	_rebuild()


func set_appearance(id: StringName) -> bool:
	if not PROFILES.has(id):
		return false
	_appearance_id = id
	if is_inside_tree():
		_rebuild()
	return true


func get_profile() -> Dictionary:
	return PROFILES[_appearance_id].duplicate(true)


func get_appearance_id() -> StringName:
	return _appearance_id


func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 1.0
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result


func _rebuild() -> void:
	if is_instance_valid(_parts):
		remove_child(_parts)
		_parts.queue_free()
	_parts = Node3D.new()
	_parts.name = "Anatomy"
	add_child(_parts)
	_skin = _material(Color(0.59, 0.47, 0.38))
	_shade = _material(Color(0.33, 0.24, 0.20))
	_hair = _material(Color(0.075, 0.065, 0.06))
	var p := get_profile()
	var vertices := PackedVector3Array()
	for ring_index in RINGS.size():
		var ring: Vector3 = RINGS[ring_index]
		var width: float = p.chin if ring_index == 0 else p.jaw if ring_index == 1 else ring.y
		for index in 12:
			var angle := TAU * float(index) / 12.0
			var point := Vector3(cos(angle) * p.depth * ring.z, ring.x * p.height, sin(angle) * p.width * width)
			if ring_index == 3 and index in [1, 11]:
				point.x += 0.018
			vertices.append(point)
	var triangles: Array[Vector3i] = []
	for ring in RINGS.size() - 1:
		for index in 12:
			var next := (index + 1) % 12
			var a := ring * 12 + index
			var b := ring * 12 + next
			var c := (ring + 1) * 12 + index
			var d := (ring + 1) * 12 + next
			triangles.append(Vector3i(a, c, b))
			triangles.append(Vector3i(b, c, d))
	_mesh("Skull", vertices, triangles, _skin)
	# Одинаковая короткая стрижка: различать нужно анатомию, а не причёску.
	var hair_vertices := vertices.duplicate()
	for i in hair_vertices.size():
		hair_vertices[i] *= 1.025
	var hair_triangles: Array[Vector3i] = []
	for triangle in triangles:
		if triangle.x >= 48 and triangle.y >= 48 and triangle.z >= 48:
			hair_triangles.append(triangle)
	var apex := hair_vertices.size()
	hair_vertices.append(Vector3(0, p.height * 0.60, 0))
	for index in 12:
		hair_triangles.append(Vector3i(72 + index, apex, 72 + (index + 1) % 12))
	_mesh("Hair", hair_vertices, hair_triangles, _hair)
	var socket_material := _material(Color(0.45, 0.34, 0.28))
	var brow_material := _material(Color(0.14, 0.105, 0.08))
	for side in [-1.0, 1.0]:
		var side_name := "Left" if side < 0 else "Right"
		_oval(side_name + "Ear", Vector3(-0.015, 0.0, side * p.width), Vector3(0.03, 0.055, 0.026), _skin)
		_oval(side_name + "EarFold", Vector3(0.01, 0.0, side * p.width), Vector3(0.005, 0.030, 0.015), _shade)
		var asym: float = p.asymmetry if side > 0 else 0.0
		var eye := Vector3(p.depth * 0.91, 0.042 + asym, side * p.eye_gap)
		_oval(side_name + "Socket", eye, Vector3(0.013, 0.021, 0.038), socket_material)
		_oval(side_name + "Eye", eye + Vector3(0.012, 0.001, 0.0), Vector3(0.009, 0.011, 0.027), _material(Color(0.53, 0.50, 0.43)))
		_oval(side_name + "Iris", eye + Vector3(0.021, 0.001, 0.0), Vector3(0.003, 0.010, 0.009), _hair)
		_box(side_name + "UpperLid", eye + Vector3(0.016, 0.012, 0), Vector3(0.014, 0.009, 0.059), _skin)
		var brow := _box(side_name + "Brow", eye + Vector3(0.005, 0.030, 0), Vector3(0.020, 0.010, 0.066), brow_material)
		brow.rotation.x = side * float(p.brow)
	var nose_width: float = p.nose_width
	var base: float = p.depth * 0.96
	var tip: float = base + p.nose
	var bend: float = p.asymmetry * 0.6
	var nose := PackedVector3Array([
		Vector3(base, 0.10, -0.014), Vector3(base, 0.10, 0.014),
		Vector3(tip - 0.015, -0.025, bend - nose_width * 0.65), Vector3(tip, -0.025, bend + nose_width * 0.65),
		Vector3(base, -0.052, -nose_width), Vector3(base, -0.052, nose_width),
		Vector3(tip - 0.023, -0.055, bend)
	])
	_mesh("Nose", nose, [Vector3i(0, 1, 3), Vector3i(0, 3, 2), Vector3i(0, 2, 4), Vector3i(1, 5, 3), Vector3i(2, 3, 6), Vector3i(2, 6, 4), Vector3i(3, 5, 6), Vector3i(4, 6, 5)], _skin)
	for side in [-1.0, 1.0]:
		_oval("Nostril", Vector3(base + p.nose * 0.42, -0.048, side * nose_width * 0.65), Vector3(0.009, 0.006, 0.009), _shade)
	var lip := _material(Color(0.40, 0.27, 0.24))
	_box("UpperLip", Vector3(p.depth * 0.96, -0.095, 0), Vector3(0.021, 0.009, p.mouth), lip)
	_box("MouthLine", Vector3(p.depth * 1.04, -0.102, 0), Vector3(0.004, 0.004, p.mouth * 0.85), _shade)
	_box("LowerLip", Vector3(p.depth * 0.96, -0.111, 0), Vector3(0.023, 0.009, p.mouth * 0.88), _skin)


func _oval(part_name: String, position_value: Vector3, radii: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 4
	return _part(part_name, mesh, position_value, radii, material)


func _box(part_name: String, position_value: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _part(part_name, mesh, position_value, Vector3.ONE, material)


func _part(part_name: String, mesh: Mesh, position_value: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.position = position_value
	part.scale = scale_value
	part.material_override = material
	_parts.add_child(part)
	return part


func _mesh(part_name: String, vertices: PackedVector3Array, triangles: Array[Vector3i], material: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in triangles:
		var a := vertices[triangle.x]
		var b := vertices[triangle.y]
		var c := vertices[triangle.z]
		var normal := (b - a).cross(c - a).normalized()
		for point in [a, c, b]:
			tool.set_normal(normal)
			tool.add_vertex(point)
	_part(part_name, tool.commit(), Vector3.ZERO, Vector3.ONE, material)
