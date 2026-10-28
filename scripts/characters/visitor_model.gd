class_name VisitorModel
extends Node3D
## CHAR-03: силуэт и степень стилизации по CHARACTER_REFERENCE.
## +Z — лицо. Геометрия в rest-пространстве, единый skinned ArrayMesh.

# Рост ~1.80 м, глаза ~1.65 м: соответствует капсуле/камере игрока.
const MODEL_SCALE: float = 1.048
const FLOOR_Y: float = -1.65

var skeleton: Skeleton3D
var talking: bool = false
var _time: float = 0.0
var _bones: Dictionary = {}
var _surfaces: Dictionary = {}
var _skin_material: StandardMaterial3D
var _cloth_material: StandardMaterial3D
var _leather: StandardMaterial3D
var is_blinking: bool = false
var _open_texture: Texture2D
var _closed_texture: Texture2D
var _gesture: float = 0.0
var _hand_frames: Dictionary = {}


func _ready() -> void:
	scale = Vector3.ONE * MODEL_SCALE
	position.y = FLOOR_Y * (1.0 - MODEL_SCALE)
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	_skin_material = _textured("res://assets/characters/test_visitor/head_wrap_v3.png")
	_open_texture = _skin_material.albedo_texture
	_closed_texture = load("res://assets/characters/test_visitor/head_blink_v3.png")
	_cloth_material = _textured("res://assets/characters/test_visitor/clothing_atlas_v3.png")
	_leather = StandardMaterial3D.new()
	_leather.albedo_color = Color(0.065, 0.053, 0.043)
	_leather.roughness = 0.88
	_leather.albedo_texture = _leather_texture()
	_leather.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_bone("Pelvis", "", Vector3(-0.018, -0.90, 0))
	_bone("Chest", "Pelvis", Vector3(0.013, 0.42, 0.025))
	_bone("Head", "Chest", Vector3(0.005, 0.41, 0.025))
	for side in [-1, 1]:
		var suffix := "L" if side < 0 else "R"
		_bone("UpperArm" + suffix, "Chest", Vector3(side * 0.205, 0.16, -0.005))
		_bone("Forearm" + suffix, "UpperArm" + suffix, Vector3(side * 0.035, -0.265, 0.065))
		# Одна рука у живота, другая на стойке: разные жесты и контуры рук.
		_bone("Hand" + suffix, "Forearm" + suffix, Vector3(0.20, 0.035, 0.12) if side < 0 else Vector3(-0.045, 0.063, 0.235))
		_bone("Thigh" + suffix, "Pelvis", Vector3(side * 0.095, 0, -0.005))
		_bone("Shin" + suffix, "Thigh" + suffix, Vector3(side * 0.017, -0.34, 0.030 if side < 0 else 0.005))
		_bone("Foot" + suffix, "Shin" + suffix, Vector3(side * 0.008, -0.32, -0.045 if side < 0 else -0.010))
	skeleton.reset_bone_poses()
	for suffix in ["L", "R"]:
		var hand: String = "Hand" + suffix
		var forward := (_origin(hand) - _origin("Forearm" + suffix)).normalized()
		var right := Vector3(forward.z, 0, -forward.x).normalized()
		_hand_frames[hand] = Basis(right, forward.cross(right).normalized(), forward)
	_build_torso()
	_build_head()
	_build_hair()
	for side in [-1, 1]:
		_build_arm(side)
		_build_leg(side)
	_commit_mesh()
	_pose(0.0)


func _textured(path: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(path)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 0.94
	return material


func _leather_texture() -> ImageTexture:
	# Собственная UV-фактура обуви: подошва, потёртый носок, шнуровка.
	var image := Image.create(128, 128, true, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var u := minf(x, 128 - x) / 128.0
			var v := y / 128.0
			var grain := float((x * 31 + y * 17 + x * y * 11) % 23) / 23.0
			var value := 0.64 + grain * 0.22
			value += exp(-pow(u / 0.18, 2) - pow((v - 0.42) / 0.17, 2)) * 0.60
			if y < 18:
				value *= 0.50 if y < 14 else 1.1
			if u < 0.10 and y in [72, 73, 83, 84, 94, 95]:
				value = 2.0
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _bone(label: String, parent: String, offset: Vector3) -> void:
	var index := skeleton.get_bone_count()
	skeleton.add_bone(label)
	_bones[label] = index
	if not parent.is_empty():
		skeleton.set_bone_parent(index, _bones[parent])
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, offset))


func _origin(label: String) -> Vector3:
	return skeleton.get_bone_global_rest(_bones[label]).origin


func _surface(label: String, material: Material) -> SurfaceTool:
	if not _surfaces.has(label):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(material)
		tool.set_smooth_group(0)
		_surfaces[label] = tool
	return _surfaces[label]


func _vertex(tool: SurfaceTool, point: Vector3, uv: Vector2, bone: String, other: String = "", blend: float = 0.0) -> void:
	if _hand_frames.has(bone):
		point = _origin(bone) + _hand_frames[bone] * (point - _origin(bone))
	if bone == "Head":
		var local := point - _origin("Head")
		point = _origin("Head") + Vector3(local.x * 1.10, local.y * 0.92 - 0.016, local.z * 1.06)
	tool.set_uv(uv)
	tool.set_bones(PackedInt32Array([_bones[bone], _bones[other] if not other.is_empty() else _bones[bone], 0, 0]))
	tool.set_weights(PackedFloat32Array([1.0 - blend, blend, 0.0, 0.0]))
	tool.add_vertex(point)


func _commit_mesh() -> void:
	var mesh := ArrayMesh.new()
	for tool: SurfaceTool in _surfaces.values():
		tool.generate_normals()
		tool.index()
		tool.commit(mesh)
	_surfaces.clear()
	var skin := Skin.new()
	for index in skeleton.get_bone_count():
		skin.add_bind(index, skeleton.get_bone_global_rest(index).affine_inverse())
	var instance := MeshInstance3D.new()
	instance.name = "CharacterMesh"
	instance.mesh = mesh
	instance.skin = skin
	instance.skeleton = NodePath("../Skeleton3D")
	instance.extra_cull_margin = 0.15
	add_child(instance)


func _body_uv(angle: float, vertical: float, front: bool) -> Vector2:
	return Vector2((0.25 + sin(angle) * 0.244) if front else (0.75 - sin(angle) * 0.244), clampf(vertical, 0.008, 0.492))


func _build_torso() -> void:
	var tool := _surface("Clothing", _cloth_material)
	# y, ширина, глубина: талия, грудь, покатые плечи, вырез воротника.
	var rings := [Vector3(-0.40, 0.183, 0.105), Vector3(-0.32, 0.181, 0.115), Vector3(-0.20, 0.163, 0.108), Vector3(-0.08, 0.187, 0.123), Vector3(0.045, 0.222, 0.133), Vector3(0.13, 0.236, 0.119), Vector3(0.17, 0.218, 0.108), Vector3(0.205, 0.143, 0.081), Vector3(0.225, 0.064, 0.065)]
	for row in rings.size() - 1:
		for column in 24:
			var front := cos(-PI + TAU * (column + 0.5) / 24.0) > 0
			for corner in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var ring: Vector3 = rings[row + corner.y]
				var angle: float = -PI + TAU * (column + corner.x) / 24.0
				var wrinkle := sin(angle * 7.0 + row * 1.3) * 0.0025
				var point := _origin("Chest") + Vector3(sin(angle) * (ring.y + wrinkle), ring.x, cos(angle) * (ring.z + wrinkle))
				var vertical := (0.225 - ring.x) / 0.625 * 0.484 + 0.008
				_vertex(tool, point, _body_uv(angle, vertical, front), "Pelvis", "Chest", smoothstep(-0.38, -0.14, ring.x))
	# Воротник — тонкие изогнутые лоскуты, без выступающих коробок.
	for side in [-1, 1]:
		var points := [Vector3(side * 0.025, 0.222, 0.063), Vector3(side * 0.076, 0.197, 0.089), Vector3(side * 0.092, 0.117, 0.133), Vector3(side * 0.043, 0.158, 0.124)]
		var order := [0, 1, 3, 1, 2, 3] if side > 0 else [0, 3, 1, 1, 3, 2]
		for index in order:
			var p: Vector3 = points[index]
			_vertex(tool, _origin("Chest") + p, Vector2(0.25 + p.x * 1.04, (0.225 - p.y) / 0.625 * 0.484 + 0.008), "Chest")
	# Шея продолжает текстуру кожи, а не однотонный цилиндр другого цвета.
	var neck := [_ring(_origin("Head") + Vector3(0, -0.205, -0.015), 0.057, 0.054, "Chest", "Head", 0.2, 0.0), _ring(_origin("Head") + Vector3(0, -0.155, -0.008), 0.052, 0.048, "Chest", "Head", 0.65, 0.5), _ring(_origin("Head") + Vector3(0, -0.105, 0), 0.048, 0.043, "Head", "", 0.0, 1.0)]
	_loft("Skin", _skin_material, neck, 16, Rect2(0.39, 0.94, 0.22, 0.045), false)


func _ring(center: Vector3, width: float, depth: float, bone: String, other: String, blend: float, vertical: float) -> Dictionary:
	return {"center": center, "width": width, "depth": depth, "bone": bone, "other": other, "blend": blend, "v": vertical}


func _loft(label: String, material: Material, rings: Array, segments: int, region: Rect2, follow: bool = true, caps: bool = false) -> void:
	var tool := _surface(label, material)
	# Ось кольца follow направлена вдоль убывающего y/к кончикам пальцев.
	# Для такой системы базиса winding противоположен восходящим кольцам тела.
	var corners := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)] if follow else [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	for row in rings.size() - 1:
		for column in segments:
			for corner in corners:
				var row_index: int = row + corner.y
				var ring: Dictionary = rings[row_index]
				var center: Vector3 = ring.center
				var forward := Vector3.BACK
				var right := Vector3.RIGHT
				if follow:
					var tangent: Vector3 = rings[mini(row_index + 1, rings.size() - 1)].center - rings[maxi(row_index - 1, 0)].center
					forward = tangent.cross(Vector3.RIGHT).normalized()
					right = forward.cross(tangent.normalized()).normalized()
				var angle: float = TAU * (column + corner.x) / float(segments)
				var point := center + right * sin(angle) * float(ring.width) + forward * cos(angle) * float(ring.depth)
				var uv := region.position + region.size * Vector2((column + corner.x) / float(segments), ring.v)
				_vertex(tool, point, uv, ring.bone, ring.other, ring.blend)
	if caps:
		for row_index in [0, rings.size() - 1]:
			var ring: Dictionary = rings[row_index]
			var center: Vector3 = ring.center
			var forward := Vector3.BACK
			var right := Vector3.RIGHT
			if follow:
				var tangent: Vector3 = rings[mini(row_index + 1, rings.size() - 1)].center - rings[maxi(row_index - 1, 0)].center
				forward = tangent.cross(Vector3.RIGHT).normalized()
				right = forward.cross(tangent.normalized()).normalized()
			for column in segments:
				var order := [-1, column, column + 1] if row_index == 0 else [-1, column + 1, column]
				if follow:
					order.reverse()
				for index in order:
					var angle: float = TAU * index / float(segments)
					var point := center if index == -1 else center + right * sin(angle) * float(ring.width) + forward * cos(angle) * float(ring.depth)
					_vertex(tool, point, region.get_center(), ring.bone, ring.other, ring.blend)


func _build_arm(side: int) -> void:
	var suffix := "L" if side < 0 else "R"
	var upper := "UpperArm" + suffix
	var forearm := "Forearm" + suffix
	var wrist := "Hand" + suffix
	var shoulder := _origin(upper)
	var elbow := _origin(forearm)
	var hand := _origin(wrist)
	var sleeve := [
		_ring(shoulder + Vector3(0, 0.010, 0), 0.010, 0.040, upper, "", 0, 0),
		_ring(shoulder - Vector3(0, 0.025, 0), 0.077, 0.082, upper, "", 0, 0.08),
		_ring(shoulder.lerp(elbow, 0.32), 0.087, 0.081, upper, "", 0, 0.24),
		_ring(shoulder.lerp(elbow, 0.72), 0.072, 0.070, upper, forearm, 0.1, 0.43),
		_ring(elbow, 0.074, 0.075, upper, forearm, 0.5, 0.53),
		_ring(elbow.lerp(hand, 0.20), 0.073, 0.067, upper, forearm, 0.95, 0.63),
		_ring(elbow.lerp(hand, 0.55), 0.064, 0.061, forearm, "", 0, 0.77),
		_ring(elbow.lerp(hand, 0.91), 0.050, 0.047, forearm, wrist, 0.05, 0.94),
		_ring(hand, 0.051, 0.045, forearm, wrist, 0.15, 1.0)]
	_loft("Clothing", _cloth_material, sleeve, 12, Rect2(0.008, 0.508, 0.484, 0.484))
	var palm := [_ring(hand, 0.033, 0.017, wrist, "", 0, 0), _ring(hand + Vector3(0, -0.009, 0.039), 0.038, 0.018, wrist, "", 0, 0.4), _ring(hand + Vector3(0, -0.015, 0.076), 0.034, 0.014, wrist, "", 0, 1)]
	_loft("Skin", _skin_material, palm, 10, Rect2(0.38, 0.94, 0.24, 0.045), true, true)
	for finger in 4:
		var x: float = (finger - 1.5) * 0.0175
		var length: float = 0.052 - absf(finger - 1.4) * 0.008
		var base := hand + Vector3(x, -0.012, 0.068)
		var curl := 0.55 if side < 0 else 0.35
		var rings := [_ring(base, 0.010, 0.011, wrist, "", 0, 0), _ring(base + Vector3(0, -0.002, length * 0.45), 0.009, 0.010, wrist, "", 0, 0.4), _ring(base + Vector3(0, -0.015 * curl, length * 0.85), 0.008, 0.009, wrist, "", 0, 0.75), _ring(base + Vector3(0, -0.029 * curl, length * 0.98), 0.005, 0.006, wrist, "", 0, 1)]
		_loft("Skin", _skin_material, rings, 8, Rect2(0.40, 0.94, 0.20, 0.045), true, true)
	var thumb := [_ring(hand + Vector3(side * 0.032, -0.007, 0.012), 0.014, 0.013, wrist, "", 0, 0), _ring(hand + Vector3(side * 0.050, -0.018, 0.042), 0.012, 0.011, wrist, "", 0, 0.5), _ring(hand + Vector3(side * 0.046, -0.028, 0.066), 0.007, 0.008, wrist, "", 0, 1)]
	_loft("Skin", _skin_material, thumb, 8, Rect2(0.41, 0.94, 0.18, 0.045), true, true)


func _build_leg(side: int) -> void:
	var suffix := "L" if side < 0 else "R"
	var thigh := "Thigh" + suffix
	var shin := "Shin" + suffix
	var foot := "Foot" + suffix
	var top := _origin(thigh)
	var knee := _origin(shin)
	var ankle := _origin(foot)
	var leg := [_ring(top + Vector3(0, 0.065, 0), 0.097, 0.101, thigh, "", 0, 0), _ring(top, 0.103, 0.110, thigh, "", 0, 0.08), _ring(top.lerp(knee, 0.30), 0.100, 0.103, thigh, "", 0, 0.22), _ring(top.lerp(knee, 0.74), 0.078, 0.080, thigh, shin, 0.12, 0.43), _ring(knee, 0.076, 0.077, thigh, shin, 0.5, 0.54), _ring(knee.lerp(ankle, 0.22), 0.080, 0.081, thigh, shin, 0.93, 0.66), _ring(knee.lerp(ankle, 0.62), 0.072, 0.071, shin, "", 0, 0.83), _ring(ankle + Vector3(0, 0.035, 0), 0.061, 0.064, shin, foot, 0.05, 0.95), _ring(ankle, 0.065, 0.067, shin, foot, 0.15, 1)]
	_loft("Clothing", _cloth_material, leg, 12, Rect2(0.508, 0.508, 0.484, 0.484))
	var boot := [_ring(ankle + Vector3(0, -0.09, 0.045), 0.065, 0.132, foot, "", 0, 0), _ring(ankle + Vector3(0, -0.075, 0.047), 0.069, 0.132, foot, "", 0, 0.12), _ring(ankle + Vector3(0, -0.04, 0.043), 0.064, 0.122, foot, "", 0, 0.5), _ring(ankle + Vector3(0, 0.008, 0.012), 0.054, 0.087, foot, "", 0, 0.83), _ring(ankle + Vector3(0, 0.046, 0), 0.050, 0.059, foot, "", 0, 1)]
	_loft("Leather", _leather, boot, 12, Rect2(0, 0, 1, 1), false, true)


func _head_uv(angle: float, vertical: float) -> Vector2:
	var normalized := absf(angle) / PI
	var horizontal := normalized * 0.70 if normalized <= 0.5 else 0.35 + (normalized - 0.5) * 0.30
	return Vector2(0.5 + signf(angle) * horizontal, vertical)


func _head_point(ring: Vector4, angle: float) -> Vector3:
	var x := sin(angle) * ring.y
	var front := maxf(cos(angle), 0)
	var depth := ring.z if front > 0 else ring.z + 0.012
	var z := cos(angle) * depth
	var nose := exp(-pow(x / 0.018, 2)) * exp(-pow((ring.x + 0.035) / 0.025, 2)) * 0.029
	var lips := exp(-pow(x / 0.032, 2)) * exp(-pow((ring.x + 0.075) / 0.014, 2)) * 0.006
	var eyes := (exp(-pow((x - 0.038) / 0.018, 2)) + exp(-pow((x + 0.038) / 0.018, 2))) * exp(-pow((ring.x - 0.015) / 0.014, 2)) * 0.005
	z += (nose + lips - eyes) * pow(front, 4)
	return Vector3(x, ring.x, z)


func _build_head() -> void:
	var tool := _surface("Skin", _skin_material)
	# y, полуширина, глубина, v атласа. Один замкнутый череп вместо лицевой маски.
	var rings := [Vector4(-0.14, 0.028, 0.035, 0.83), Vector4(-0.12, 0.056, 0.053, 0.79), Vector4(-0.095, 0.071, 0.065, 0.74), Vector4(-0.075, 0.077, 0.073, 0.68), Vector4(-0.045, 0.084, 0.081, 0.61), Vector4(-0.015, 0.088, 0.083, 0.53), Vector4(0.015, 0.091, 0.081, 0.445), Vector4(0.040, 0.092, 0.080, 0.37), Vector4(0.075, 0.091, 0.078, 0.28), Vector4(0.110, 0.086, 0.073, 0.18), Vector4(0.142, 0.064, 0.055, 0.08), Vector4(0.162, 0.022, 0.023, 0.015)]
	for row in rings.size() - 1:
		for column in 40:
			for corner in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var ring: Vector4 = rings[row + corner.y]
				var angle: float = -PI + TAU * (column + corner.x) / 40.0
				_vertex(tool, _origin("Head") + _head_point(ring, angle), _head_uv(angle, ring.w), "Head")
	# Темя закрыто треугольным веером, UV-шов остаётся сзади.
	for column in 40:
		for index in [-1, column + 1, column]:
			var angle: float = -PI + TAU * index / 40.0
			var point := Vector3(0, 0.167, 0) if index == -1 else _head_point(rings[-1], angle)
			_vertex(tool, _origin("Head") + point, Vector2(0.5, 0.01) if index == -1 else _head_uv(angle, 0.01), "Head")
	# Уши получают соответствующие участки UV, без однотонных вставок.
	for side in [-1, 1]:
		var center := _origin("Head") + Vector3(side * 0.091, -0.005, -0.004)
		var corners := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] if side > 0 else [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
		for row in 6:
			for column in 10:
				for corner in corners:
					var latitude: float = PI * (row + corner.y + 0.01) / 6.02
					var longitude: float = TAU * (column + corner.x) / 10.0
					var p := Vector3(side * sin(latitude) * cos(longitude) * 0.013, cos(latitude) * 0.028, sin(latitude) * sin(longitude) * 0.017)
					var uv := Vector2((0.175 if side < 0 else 0.825) + p.z * 1.5 * side, 0.495 - p.y * 2.8)
					_vertex(tool, center + p, uv, "Head")


func _build_hair() -> void:
	# Замкнутые низкополигональные пряди меняют силуэт и ловят свет.
	var tool := _surface("Skin", _skin_material)
	tool.set_smooth_group(-1)
	for index in 5:
		var x := -0.064 + index * 0.030
		var root := Vector3(x, 0.125 + sin(index * 0.95) * 0.014, 0.055)
		var tip := Vector3(x - (0.018 if index < 3 else -0.006), 0.052 + (index % 3) * 0.013, 0.088 + sin(index) * 0.006)
		_hair_lock(tool, root, tip, 0.025 if index < 4 else 0.021, Vector3.BACK)
	for side in [-1, 1]:
		_hair_lock(tool, Vector3(side * 0.080, 0.112, 0.012), Vector3(side * 0.101, 0.015, 0.034), 0.019, Vector3(side, 0, 0.4).normalized())
		_hair_lock(tool, Vector3(side * 0.050, 0.145, -0.022), Vector3(side * 0.085, 0.105, -0.069), 0.025, Vector3(side * 0.5, 0.5, -0.7).normalized())
	tool.set_smooth_group(0)


func _hair_lock(tool: SurfaceTool, root: Vector3, tip: Vector3, width: float, outward: Vector3) -> void:
	var sideways := (tip - root).cross(outward).normalized() * width
	var points := [root - sideways, root + sideways, root - sideways - outward * 0.012, root + sideways - outward * 0.012, tip, root.lerp(tip, 0.48) + outward * 0.014]
	var center := Vector3.ZERO
	for point: Vector3 in points:
		center += point / float(points.size())
	for face: Vector3i in [Vector3i(0, 1, 5), Vector3i(1, 4, 5), Vector3i(4, 0, 5), Vector3i(0, 4, 2), Vector3i(1, 3, 4), Vector3i(2, 4, 3), Vector3i(2, 3, 1), Vector3i(2, 1, 0)]:
		var order := [face.x, face.y, face.z]
		var normal: Vector3 = (points[face.y] - points[face.x]).cross(points[face.z] - points[face.x])
		var radial: Vector3 = (points[face.x] + points[face.y] + points[face.z]) / 3.0 - center
		if normal.dot(radial) > 0:
			order.reverse()
		for index in order:
			var uv := Vector2(0.035 + (index % 2) * 0.10, 0.075 + (0.20 if index == 4 else 0.08 if index == 5 else 0.0))
			_vertex(tool, _origin("Head") + points[index], uv, "Head")


func _pose(delta: float) -> void:
	_gesture = move_toward(_gesture, 1.0 if talking else 0.0, delta * 2.5)
	skeleton.set_bone_pose_rotation(_bones.Pelvis, Quaternion.from_euler(Vector3(0, 0.018, -0.025)))
	skeleton.set_bone_pose_rotation(_bones.Chest, Quaternion.from_euler(Vector3(0.035 + sin(_time * 1.25) * 0.006, -0.025, 0.014)))
	skeleton.set_bone_pose_rotation(_bones.Head, Quaternion.from_euler(Vector3(-0.025 + sin(_time * 0.75) * 0.009, 0.025 + sin(_time * 0.38) * 0.035, -0.018)))
	var beat := sin(_time * 1.55) * 0.5 + 0.5
	skeleton.set_bone_pose_rotation(_bones.ForearmR, Quaternion.from_euler(Vector3(-0.015 - _gesture * beat * 0.10, _gesture * 0.035, 0.015)))
	skeleton.set_bone_pose_rotation(_bones.HandR, Quaternion.from_euler(Vector3(-0.015 + _gesture * beat * 0.025, 0.015, -0.015)))
	# Ладонь уже ориентирована по предплечью в rest-геометрии; большой поворот ломал запястье.
	skeleton.set_bone_pose_rotation(_bones.HandL, Quaternion.from_euler(Vector3(0.015, -0.025, 0.02)))
	# Два совпадающих UV-кадра дают короткое закрытие глаз без накладок.
	var phase := fmod(_time + 1.5, 4.8)
	var blink_now := phase < 0.13
	if is_blinking != blink_now:
		is_blinking = blink_now
		_skin_material.albedo_texture = _closed_texture if is_blinking else _open_texture


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_pose(delta)
