class_name SmallBottleVisual
extends Node3D
## Одна геометрия для мира и рендера предмета на 2D-столе. Размеры в метрах.

const ID: StringName = &"test_stvor"
const CAPACITY: float = 250.0
var cap: Node3D
var body: Node3D

func _ready() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.64, 0.73, 0.63, 0.72)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	glass.metallic = 0.25
	glass.roughness = 0.24
	# Грани прямоугольного флакона со скруглениями, плечики и открытая горловина.
	var rings := [Vector3(0.031, -0.10, 0.019), Vector3(0.036, -0.095, 0.023), Vector3(0.036, 0.025, 0.023), Vector3(0.032, 0.045, 0.021), Vector3(0.014, 0.064, 0.014), Vector3(0.012, 0.08, 0.012), Vector3(0.012, 0.098, 0.012), Vector3(0.009, 0.098, 0.009), Vector3(0.009, 0.075, 0.009)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rings.size() - 1):
		for segment in 24:
			var corners := [_vertex(rings[row], segment, row), _vertex(rings[row], segment + 1, row), _vertex(rings[row + 1], segment + 1, row + 1), _vertex(rings[row + 1], segment, row + 1)]
			for index in [0, 1, 2, 0, 2, 3]: surface.add_vertex(corners[index])
	for segment in 24:
		surface.add_vertex(Vector3(0, -0.10, 0))
		surface.add_vertex(_vertex(rings[0], segment + 1, 0))
		surface.add_vertex(_vertex(rings[0], segment, 0))
	surface.generate_normals()
	var shell := MeshInstance3D.new()
	shell.name = "Glass"
	shell.mesh = surface.commit()
	shell.material_override = glass
	body.add_child(shell)
	for height in [0.082, 0.088, 0.094]:
		var rim := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.010
		torus.outer_radius = 0.013
		torus.rings = 24
		torus.ring_segments = 8
		rim.mesh = torus
		rim.position.y = height
		rim.material_override = glass
		body.add_child(rim)
	var label := MeshInstance3D.new()
	label.name = "Label"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.058, 0.096)
	label.mesh = quad
	label.position = Vector3(0, -0.028, 0.0235)
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = preload("res://assets/drinks/stvor_label.svg")
	paper.roughness = 0.95
	label.material_override = paper
	body.add_child(label)
	for entry in [["СЕВЕРНЫЙ\nСТВОР", -0.037, 40], ["0,25 л", -0.067, 32]]:
		var lettering := Label3D.new()
		lettering.text = entry[0]
		lettering.font_size = entry[2]
		lettering.pixel_size = 0.00019
		lettering.outline_size = 0
		lettering.modulate = Color(0.12, 0.18, 0.19)
		lettering.position = Vector3(0, entry[1], 0.024)
		lettering.no_depth_test = false
		body.add_child(lettering)
	cap = Node3D.new()
	cap.name = "Cap"
	add_child(cap)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.62, 0.64, 0.60)
	metal.metallic = 0.65
	metal.roughness = 0.4
	var lid := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.0145
	cylinder.bottom_radius = 0.0145
	cylinder.height = 0.023
	cylinder.radial_segments = 32
	lid.mesh = cylinder
	lid.position.y = 0.094
	lid.material_override = metal
	cap.add_child(lid)
	for index in 24:
		var rib := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.0012, 0.013, 0.0012)
		rib.mesh = box
		var angle := TAU * index / 24.0
		rib.position = Vector3(cos(angle) * 0.0145, 0.098, sin(angle) * 0.0145)
		rib.material_override = metal
		cap.add_child(rib)

func _vertex(ring: Vector3, segment: int, row: int) -> Vector3:
	var angle := TAU * segment / 24.0
	var exponent := 0.4 if row < 4 else 1.0
	return Vector3(signf(cos(angle)) * pow(absf(cos(angle)), exponent) * ring.x, ring.y, signf(sin(angle)) * pow(absf(sin(angle)), exponent) * ring.z)

func set_capped(value: bool) -> void:
	cap.visible = value

static func make_preview(parent: Node, cap_only: bool = false) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192, 320) if not cap_only else Vector2i(96, 96)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(viewport)
	var visual := SmallBottleVisual.new()
	visual.name = "Bottle"
	viewport.add_child(visual)
	visual.body.visible = not cap_only
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.222 if not cap_only else 0.037
	viewport.add_child(camera)
	var target := Vector3(0, 0.0025, 0) if not cap_only else Vector3(0, 0.094, 0)
	camera.position = target + Vector3(0, 0.012 if not cap_only else 0.16, 0.6)
	camera.look_at(target)
	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	light.rotation_degrees = Vector3(-25, -30, 0)
	light.light_energy = 1.5
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.78, 0.82, 0.77)
	environment.environment.ambient_light_energy = 0.7
	viewport.add_child(environment)
	return viewport
