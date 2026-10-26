extends Node3D
## TEST-внешность с заменяемой анатомией лица, без канонической личности.

static var _appearance: StringName = &"test_face_a"
var _face: TestFace
var _control: OptionButton


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


func configure_controls(hud: NavigationHUD) -> void:
	_control = hud.get_node("%TestFace")
	_control.select(TestFace.get_appearance_ids().find(_appearance))
	_control.item_selected.connect(func(index: int) -> void: set_test_appearance(TestFace.get_appearance_ids()[index]))


func set_test_appearance(id: StringName) -> bool:
	if not _face.set_appearance(id):
		return false
	_appearance = id
	if is_instance_valid(_control):
		_control.select(TestFace.get_appearance_ids().find(id))
	return true


func get_test_appearance() -> StringName:
	return _appearance
