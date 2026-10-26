extends Node3D
## TEST-силуэт: гранёные формы и ткань, без канонической личности.


func _ready() -> void:
	var coat := ShaderMaterial.new()
	coat.shader = preload("res://assets/shaders/worn_surface.gdshader")
	coat.set_shader_parameter("tint", Color(0.29, 0.32, 0.22))
	coat.set_shader_parameter("surface_kind", 3)
	for name in ["Torso", "LeftArm", "RightArm"]:
		get_node(name).material_override = coat
	for name in ["Head", "Hair", "Torso"]:
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 8
		mesh.rings = 1
		mesh.height = 1.0
		mesh.top_radius = 0.43 if name == "Torso" else 0.5
		mesh.bottom_radius = 0.5
		get_node(name).mesh = mesh
	for z in [-0.065, 0.065]:
		var brow := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(0.014, 0.017, 0.055)
		brow.mesh = shape
		brow.position = Vector3(0.161, 0.073, z)
		brow.material_override = $Hair.material_override
		add_child(brow)
