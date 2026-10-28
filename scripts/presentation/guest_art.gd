extends Node3D
## TEST-внешность с заменяемой анатомией лица, без канонической личности.

static var _appearance: StringName = &"test_face_a"
static var _prototype_enabled: bool = true
var _face: TestFace
var _control: OptionButton
var _prototype: VisitorModel


func _ready() -> void:
	var coat := ShaderMaterial.new()
	coat.shader = preload("res://assets/shaders/worn_surface.gdshader")
	coat.set_shader_parameter("tint", Color(0.29, 0.32, 0.22))
	coat.set_shader_parameter("surface_kind", 3)
	for name in ["Torso", "LeftArm", "RightArm"]:
		get_node(name).material_override = coat
	for name in ["Torso"]:
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 8
		mesh.rings = 1
		mesh.height = 1.0
		mesh.top_radius = 0.43 if name == "Torso" else 0.5
		mesh.bottom_radius = 0.5
		get_node(name).mesh = mesh
	_face = $TestFace
	_face.set_appearance(_appearance)
	_prototype = preload("res://scenes/characters/visitor_model.tscn").instantiate()
	_prototype.rotation.y = PI / 2
	add_child(_prototype)
	_update_visibility()


func configure_controls(hud: NavigationHUD) -> void:
	_control = hud.get_node("%TestFace")
	_control.add_item("D · Текстурированный посетитель", 3)
	_control.select(3 if _prototype_enabled else TestFace.get_appearance_ids().find(_appearance))
	_control.item_selected.connect(func(index: int) -> void:
		set_test_appearance(&"test_visitor" if index == 3 else TestFace.get_appearance_ids()[index])
	)
	var session := hud.get_parent().get_node("NarrativeSession") as NarrativeSession
	session.mode_changed.connect(func(mode: StringName) -> void:
		_prototype.talking = mode == NarrativeSession.DIALOGUE
	)


func set_test_appearance(id: StringName) -> bool:
	if id == &"test_visitor":
		_prototype_enabled = true
		_update_visibility()
		if is_instance_valid(_control):
			_control.select(3)
		return true
	if not _face.set_appearance(id):
		return false
	_appearance = id
	_prototype_enabled = false
	_update_visibility()
	if is_instance_valid(_control):
		_control.select(TestFace.get_appearance_ids().find(id))
	return true


func get_test_appearance() -> StringName:
	return &"test_visitor" if _prototype_enabled else _appearance


func _update_visibility() -> void:
	for child in get_children():
		if child is Node3D:
			child.visible = _prototype_enabled if child == _prototype else not _prototype_enabled
	get_parent().configure_body_scale(VisitorModel.MODEL_SCALE if _prototype_enabled else 1.0)


func get_dialogue_head_position() -> Vector3:
	return _prototype.to_global(Vector3(0, 0.22, 0)) if _prototype_enabled else global_position + Vector3.UP * 0.36


func get_dialogue_face_position() -> Vector3:
	if _prototype_enabled:
		var head := _prototype.skeleton.get_bone_global_pose(_prototype.skeleton.find_bone("Head")).origin
		return _prototype.to_global(head + Vector3(0, 0.0, 0.08))
	return global_position + Vector3.UP * 0.06
