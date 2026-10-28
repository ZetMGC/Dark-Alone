class_name VisitorModel
extends Node3D
## CHAR-06: контакт опорной кисти и жесты на время набора реплики.
## +Z — лицо. Геометрия в rest-пространстве, единый skinned ArrayMesh.

# На 5% больше CHAR-04: ~1.89 м; масштаб по-прежнему считается от пола.
const MODEL_SCALE: float = 1.1004
const FLOOR_Y: float = -1.65

var skeleton: Skeleton3D
var talking: bool = false
var speaking: bool = false
var _speech_time: float = 0.0
var _line_variant: int = 0
var _support_points: PackedVector3Array = []
var _motion: Vector3 = Vector3.ZERO
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
var behavior_enabled: bool = false
var walk_speed: float = 0.0
var travel_distance: float = 0.0
var support_weight: float = 1.0
var look_target: Vector3 = Vector3.ZERO
var attention: bool = false
var reaction: StringName = &"neutral"
var reaction_time: float = 0.0
var drink_weight: float = 0.0
var drink_target: Vector3 = Vector3.ZERO
var _look: Vector2 = Vector2.ZERO
var _walking: float = 0.0
var _foot_locks: Dictionary = {}
var _foot_swing: Dictionary = {}
var _idle_time: float = 0.0
var _idle_next: float = 7.3
var _idle_variant: int = 0


func react(kind: StringName) -> void:
	if kind not in [&"interested", &"thoughtful", &"tense", &"disagree", &"neutral"]:
		return
	reaction = kind
	reaction_time = 0.0


func hand_transform() -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_bones.HandR)


func _aim_bone(index: int, rest_direction: Vector3, direction: Vector3) -> void:
	var parent := skeleton.get_bone_parent(index)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var desired := Basis(Quaternion(rest_direction.normalized(), direction.normalized()))
	skeleton.set_bone_pose_rotation(index, (parent_basis.inverse() * desired).get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()


func _limb(upper: String, lower: String, end: String, target: Vector3, pole: Vector3) -> void:
	var root := skeleton.get_bone_global_pose(_bones[upper]).origin
	var a := _origin(lower) - _origin(upper)
	var b := _origin(end) - _origin(lower)
	var axis := (target - root).normalized()
	var distance := clampf(root.distance_to(target), 0.02, (a.length() + b.length()) * 0.997)
	var along := (a.length_squared() - b.length_squared() + distance * distance) / (2.0 * distance)
	var bend := (pole - axis * pole.dot(axis)).normalized()
	var elbow := root + axis * along + bend * sqrt(maxf(0, a.length_squared() - along * along))
	_aim_bone(_bones[upper], a, elbow - root)
	_aim_bone(_bones[lower], b, root + axis * distance - elbow)


func _behavior_pose(delta: float) -> void:
	var stationary := support_weight * (1.0 - _walking)
	var sipping := clampf(drink_weight, 0, 1) * stationary
	var conversational := stationary * (1.0 - sipping)
	var gait := travel_distance / 0.86 * TAU
	skeleton.set_bone_pose_position(_bones.Pelvis, skeleton.get_bone_rest(_bones.Pelvis).origin - Vector3.UP * (0.075 + cos(gait * 2) * 0.004) * _walking)
	skeleton.force_update_all_bone_transforms()
	var local_look := to_local(look_target) - skeleton.get_bone_global_pose(_bones.Head).origin
	var yaw := atan2(local_look.x, local_look.z)
	var desired := Vector2(clampf(yaw, -0.60, 0.60), clampf(-atan2(local_look.y, Vector2(local_look.x, local_look.z).length()), -0.18, 0.20)) if attention and absf(yaw) < 1.5 else Vector2.ZERO
	_look = _look.lerp(desired, 1.0 - exp(-delta * 4))
	reaction_time += delta
	var response := sin(clampf(reaction_time / 2.2, 0, 1) * PI) * conversational
	var listening := talking and not speaking
	var head := skeleton.get_bone_pose_rotation(_bones.Head).get_euler()
	head += Vector3(_look.y, _look.x, 0)
	if listening:
		head.x += 0.035 * sin(_time * 1.1) * conversational
		head.z += 0.04 * conversational
	if reaction == &"disagree":
		head.y += sin(reaction_time * 8) * response * 0.12
	elif reaction == &"thoughtful":
		head += Vector3(0.015, 0.16, 0.06) * response
	elif reaction == &"tense":
		head.x -= response * 0.06
	elif reaction == &"interested":
		head.x += response * 0.06
	skeleton.set_bone_pose_rotation(_bones.Head, Quaternion.from_euler(head))
	var chest := skeleton.get_bone_pose_rotation(_bones.Chest).get_euler()
	chest.x += (0.04 if reaction == &"interested" else -0.025 if reaction == &"tense" else 0.0) * response
	chest.x += _gesture * 0.012 * conversational
	_idle_time += delta
	if _idle_time > _idle_next and not talking and walk_speed < 0.01:
		_idle_time = 0.0
		_idle_variant += 1
		_idle_next = 6.8 + fmod(_idle_variant * 4.73, 6.0)
	var idle := sin(clampf(_idle_time / 2.0, 0, 1) * PI) if not talking else 0.0
	chest.z += idle * 0.012 * (-1 if _idle_variant % 2 else 1) * conversational
	skeleton.set_bone_pose_rotation(_bones.Chest, Quaternion.from_euler(chest))
	skeleton.force_update_all_bone_transforms()
	# Контакт — часть исходной позы; IK напитка/ходьбы плавно заменяет её.
	_place_support_hand(stationary * (1.0 - sipping))
	var phase := travel_distance / 0.86 * TAU
	for side in [-1, 1]:
		var suffix := "L" if side < 0 else "R"
		var upper: String = "UpperArm" + suffix
		var lower: String = "Forearm" + suffix
		var hand: String = "Hand" + suffix
		var arm_target := skeleton.get_bone_global_pose(_bones[upper]).origin + Vector3(side * 0.035, -0.49, sin(phase + (PI if side > 0 else 0.0)) * 0.10)
		var arm_blend := maxf(_walking, 1.0 - support_weight)
		if arm_blend > 0.001:
			# +Z — лицо: опущенный локоть направлен назад и немного наружу.
			_blend_arm(upper, lower, hand, arm_target, Vector3(side * 0.15, 0, -1), arm_blend)
		var thigh: String = "Thigh" + suffix
		var shin: String = "Shin" + suffix
		var foot: String = "Foot" + suffix
		var rest := _origin(foot)
		var fraction := fposmod(travel_distance / 0.86 + (0.5 if side > 0 else 0.0), 1.0)
		var ground := to_global(rest)
		if not _foot_locks.has(suffix):
			_foot_locks[suffix] = ground
		if fraction < 0.6:
			_foot_swing[suffix] = _foot_locks[suffix]
		else:
			var progress := (fraction - 0.6) / 0.4
			var landing := to_global(rest + Vector3(0, 0, 0.22))
			_foot_locks[suffix] = (_foot_swing.get(suffix, ground) as Vector3).lerp(landing, smoothstep(0, 1, progress)) + Vector3.UP * sin(progress * PI) * 0.07
		if _walking > 0.001:
			var target_foot := rest.lerp(to_local(_foot_locks[suffix]), _walking)
			_limb(thigh, shin, foot, target_foot, Vector3(0, 0, 1))
			skeleton.set_bone_pose_rotation(_bones[foot], skeleton.get_bone_global_pose(_bones[shin]).basis.inverse().get_rotation_quaternion())
		else:
			_foot_locks[suffix] = ground
			for bone in [thigh, shin, foot]:
				skeleton.set_bone_pose_rotation(_bones[bone], Quaternion.IDENTITY)
	if sipping > 0:
		_blend_arm("UpperArmR", "ForearmR", "HandR", to_local(drink_target), Vector3(0.65, -1.0, 0.12), sipping, true)


func _blend_arm(upper: String, lower: String, hand: String, target: Vector3, pole: Vector3, weight: float, keep_palm: bool = false) -> void:
	# Смешиваем готовые повороты цепочки, а не цель с другим полюсом локтя.
	# Иначе даже 1% ходьбы мгновенно выворачивал плечо в другую плоскость.
	var upper_from := skeleton.get_bone_pose_rotation(_bones[upper])
	var lower_from := skeleton.get_bone_pose_rotation(_bones[lower])
	var hand_from := skeleton.get_bone_pose_rotation(_bones[hand])
	var palm := skeleton.get_bone_global_pose(_bones[hand]).basis
	_limb(upper, lower, hand, target, pole)
	var hand_to := hand_from
	if keep_palm:
		hand_to = (skeleton.get_bone_global_pose(_bones[lower]).basis.inverse() * palm).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(_bones[upper], upper_from.slerp(skeleton.get_bone_pose_rotation(_bones[upper]), weight))
	skeleton.set_bone_pose_rotation(_bones[lower], lower_from.slerp(skeleton.get_bone_pose_rotation(_bones[lower]), weight))
	skeleton.set_bone_pose_rotation(_bones[hand], hand_from.slerp(hand_to, weight))
	skeleton.force_update_all_bone_transforms()


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
		_bone("Hand" + suffix, "Forearm" + suffix, Vector3(0.20, 0.035, 0.12) if side < 0 else Vector3(-0.045, 0.010, 0.235))
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
	_cache_support_points()
	_pose(0.0)


func begin_line(key: String) -> void:
	# Вариант повторяемый: загрузка той же реплики не меняет её характер.
	_line_variant = posmod(key.hash(), 3)
	_speech_time = 0.0


func _cache_support_points() -> void:
	var hand: int = _bones.HandR
	var inverse := skeleton.get_bone_global_rest(hand).affine_inverse()
	var mesh: Mesh = $CharacterMesh.mesh
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for index in vertices.size():
			if bones[index * 4] == hand and weights[index * 4] > 0.99:
				_support_points.append(inverse * vertices[index])


func _place_support_hand(weight: float = 1.0) -> void:
	# Контакт для TEST-позы у стойки высотой 1.16 м от пола гостя.
	# Поднимается предплечье целиком: кисть не отрывается от манжеты.
	var forearm: int = _bones.ForearmR
	skeleton.set_bone_pose_position(forearm, skeleton.get_bone_rest(forearm).origin)
	skeleton.force_update_all_bone_transforms()
	var hand_world := skeleton.global_transform * skeleton.get_bone_global_pose(_bones.HandR)
	var bottom := INF
	for point in _support_points:
		bottom = minf(bottom, (hand_world * point).y)
	var surface_y: float = get_parent().to_global(Vector3(0, FLOOR_Y + 1.16, 0)).y + 0.003
	var parent_world := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.get_bone_parent(forearm))
	var correction := parent_world.basis.inverse() * Vector3(0, clampf(surface_y - bottom, -0.08, 0.08) * weight, 0)
	skeleton.set_bone_pose_position(forearm, skeleton.get_bone_rest(forearm).origin + correction)
	skeleton.force_update_all_bone_transforms()


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
	# Запястье заходит внутрь манжеты, чтобы при жесте не открывалась щель.
	var palm := [_ring(hand + Vector3(0, 0, -0.035), 0.031, 0.017, wrist, "", 0, 0), _ring(hand, 0.033, 0.017, wrist, "", 0, 0.15), _ring(hand + Vector3(0, -0.009, 0.039), 0.038, 0.018, wrist, "", 0, 0.4), _ring(hand + Vector3(0, -0.015, 0.076), 0.034, 0.014, wrist, "", 0, 1)]
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
	# Ухо вытянуто из самого черепа под существующий UV-рисунок: один контур.
	var ear := exp(-pow((absf(angle) - 1.46) / 0.19, 2) - pow((ring.x + 0.005) / 0.031, 2)) * 0.013
	x += signf(angle) * ear
	var front := maxf(cos(angle), 0)
	var rear_depth := lerpf(0.030, 0.095, smoothstep(-0.145, -0.020, ring.x)) if ring.x < 0.075 else ring.z + 0.012
	var depth := ring.z if front > 0 else rear_depth
	var z := cos(angle) * depth
	var nose := exp(-pow(x / 0.015, 2)) * exp(-pow((ring.x + 0.035) / 0.021, 2)) * 0.026
	var lips := exp(-pow(x / 0.028, 2)) * (exp(-pow((ring.x + 0.069) / 0.009, 2)) * 0.004 + exp(-pow((ring.x + 0.083) / 0.009, 2)) * 0.004)
	var eyes := (exp(-pow((x - 0.038) / 0.018, 2)) + exp(-pow((x + 0.038) / 0.018, 2))) * exp(-pow((ring.x - 0.015) / 0.014, 2)) * 0.005
	z += (nose + lips - eyes) * pow(front, 4)
	return Vector3(x, ring.x, z)


func _build_head() -> void:
	var tool := _surface("Skin", _skin_material)
	# y, полуширина, глубина, v атласа. Один замкнутый череп вместо лицевой маски.
	var rings := [Vector4(-0.145, 0.026, 0.054, 0.84), Vector4(-0.133, 0.046, 0.077, 0.816), Vector4(-0.115, 0.063, 0.081, 0.78), Vector4(-0.095, 0.074, 0.081, 0.74), Vector4(-0.081, 0.078, 0.082, 0.698), Vector4(-0.069, 0.079, 0.084, 0.666), Vector4(-0.055, 0.082, 0.080, 0.633), Vector4(-0.042, 0.084, 0.078, 0.602), Vector4(-0.025, 0.087, 0.077, 0.556), Vector4(-0.010, 0.089, 0.079, 0.516), Vector4(0.015, 0.091, 0.081, 0.445), Vector4(0.040, 0.092, 0.080, 0.37), Vector4(0.075, 0.091, 0.078, 0.28), Vector4(0.110, 0.086, 0.073, 0.18), Vector4(0.142, 0.064, 0.055, 0.08), Vector4(0.162, 0.022, 0.023, 0.015)]
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
	# Закрытый низ челюсти перекрывается шеей без открытого среза.
	for column in 40:
		for index in [-1, column, column + 1]:
			var angle: float = -PI + TAU * index / 40.0
			var point := Vector3(0, -0.145, -0.005) if index == -1 else _head_point(rings[0], angle)
			_vertex(tool, _origin("Head") + point, Vector2(0.5, 0.90) if index == -1 else _head_uv(angle, 0.84), "Head")


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
	# Каждый кадр начинается с rest: результат предыдущего IK не накапливается.
	skeleton.reset_bone_poses()
	var conversational := 1.0
	if behavior_enabled:
		_walking = lerpf(_walking, clampf(walk_speed / 0.65, 0, 1), 1.0 - exp(-delta * 7.0))
		if walk_speed < 0.001 and _walking < 0.001:
			_walking = 0
		conversational = support_weight * (1.0 - _walking) * (1.0 - clampf(drink_weight, 0, 1))
	_gesture = move_toward(_gesture, conversational if talking and speaking else 0.0, delta * 2.5)
	if talking and speaking:
		_speech_time += delta
	var cycle := _speech_time / 2.2
	var variant := (int(cycle) + _line_variant) % 3
	var envelope := pow(sin(fmod(cycle, 1.0) * PI), 2) * _gesture
	var target := Vector3(envelope if variant == 0 else 0.0, envelope if variant == 1 else 0.0, envelope if variant == 2 else 0.0)
	_motion = _motion.lerp(target, 1.0 - exp(-delta * 10.0))
	var explain := _motion.x * conversational
	var emphasize := _motion.y * conversational
	var consider := _motion.z * conversational
	skeleton.set_bone_pose_rotation(_bones.Pelvis, Quaternion.from_euler(Vector3(0, 0.018, -0.025)))
	skeleton.set_bone_pose_rotation(_bones.Chest, Quaternion.from_euler(Vector3(0.035 + sin(_time * 1.25) * 0.006, -0.025 + explain * 0.025, 0.014)))
	skeleton.set_bone_pose_rotation(_bones.Head, Quaternion.from_euler(Vector3(-0.025 + sin(_time * 0.75) * 0.009 + emphasize * 0.075, 0.025 + sin(_time * 0.38) * 0.035 - explain * 0.06, -0.018 + consider * 0.07)))
	skeleton.set_bone_pose_rotation(_bones.ForearmR, Quaternion.from_euler(Vector3(-0.015, 0.015, 0.015)))
	skeleton.set_bone_pose_rotation(_bones.HandR, Quaternion.from_euler(Vector3(-0.015, 0.015, -0.015)))
	skeleton.set_bone_pose_rotation(_bones.UpperArmL, Quaternion.from_euler(Vector3(-explain * 0.08, 0, emphasize * 0.025)))
	skeleton.set_bone_pose_rotation(_bones.ForearmL, Quaternion.from_euler(Vector3(-emphasize * 0.10, explain * 0.10, explain * 0.24 + emphasize * 0.12)))
	# Ладонь уже ориентирована по предплечью в rest-геометрии; большой поворот ломал запястье.
	skeleton.set_bone_pose_rotation(_bones.HandL, Quaternion.from_euler(Vector3(0.015 + emphasize * 0.045, -0.025 - explain * 0.10, 0.02 - explain * 0.08)))
	if behavior_enabled:
		_behavior_pose(delta)
	if not behavior_enabled:
		_place_support_hand()
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
