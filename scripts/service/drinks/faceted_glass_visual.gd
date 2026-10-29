class_name FacetedGlassVisual
extends Node3D
## Стакан «Гранитоль», 240 мл: общая форма, слои жидкости и лёд для 3D/2D.
const HEIGHT := 0.105
const RADIUS := 0.034
var materials: Array[StandardMaterial3D] = []
var contents: Node3D
var _contents_hash: int = -1

func _ready() -> void:
	_build()

func _build() -> void:
	if contents != null: return
	var glass := _material(Color(0.67, 0.79, 0.74, 0.23))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.render_priority = 2
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Профиль замкнут на дне, стенки имеют реальную толщину; сверху открыто.
	var profile := [Vector2(0, 0), Vector2(0.027, 0), Vector2(0.029, 0.008), Vector2(RADIUS, HEIGHT - 0.008), Vector2(RADIUS, HEIGHT), Vector2(RADIUS - 0.0025, HEIGHT), Vector2(0.026, 0.009), Vector2(0, 0.009)]
	for row in range(profile.size() - 1):
		for side in 12:
			var corners := [_point(profile[row], side), _point(profile[row], side + 1), _point(profile[row + 1], side + 1), _point(profile[row + 1], side)]
			for index in [0, 1, 2, 0, 2, 3]:
				surface.set_smooth_group(-1)
				surface.add_vertex(corners[index])
	surface.generate_normals()
	_mesh(self, "Glass", surface.commit(), glass, Vector3.ZERO)
	var rim := TorusMesh.new()
	rim.inner_radius = RADIUS - 0.0025
	rim.outer_radius = RADIUS
	rim.rings = 12
	rim.ring_segments = 6
	_mesh(self, "Rim", rim, _material(Color(0.65, 0.75, 0.69, 0.75)), Vector3(0, HEIGHT, 0))
	var bottom := CylinderMesh.new()
	bottom.top_radius = 0.028
	bottom.bottom_radius = 0.027
	bottom.height = 0.007
	bottom.radial_segments = 12
	_mesh(self, "ThickBase", bottom, _material(Color(0.53, 0.65, 0.59, 0.58)), Vector3(0, 0.004, 0))
	var stamp := Label3D.new()
	stamp.name = "MakerMark"
	stamp.text = "ГРАНИТОЛЬ"
	stamp.font_size = 28
	stamp.pixel_size = 0.000075
	stamp.outline_size = 0
	stamp.modulate = Color(0.66, 0.74, 0.67, 0.75)
	stamp.position = Vector3(0, 0.012, 0.0295)
	add_child(stamp)
	contents = Node3D.new()
	contents.name = "Contents"
	add_child(contents)

func _point(profile: Vector2, side: int) -> Vector3:
	var angle := TAU * side / 12.0
	return Vector3(cos(angle) * profile.x, profile.y, sin(angle) * profile.x)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.2
	if color.a < 1: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials.append(material)
	return material

func _mesh(parent: Node, id: String, mesh: Mesh, material: Material, at: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.name = id
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)

func set_contents(view: Dictionary) -> bool:
	_build()
	var next_hash := hash(view)
	if next_hash == _contents_hash: return false
	_contents_hash = next_hash
	for child in contents.get_children():
		if child is MeshInstance3D: materials.erase(child.material_override)
		child.free()
	if view.is_empty(): return true
	var bottom := 0.010
	for index in view.layers.size():
		var layer: Dictionary = view.layers[index]
		var height := 0.086 * float(layer.volume_ml) / float(view.vessel.capacity_ml)
		if height <= 0: continue
		var liquid := CylinderMesh.new()
		liquid.height = height
		liquid.bottom_radius = lerpf(0.025, 0.030, (bottom - 0.010) / 0.086)
		liquid.top_radius = lerpf(0.025, 0.030, (bottom + height - 0.010) / 0.086)
		liquid.radial_segments = 12
		var color: Array = layer.color
		_mesh(contents, "Layer%d" % index, liquid, _material(Color(color[0], color[1], color[2])), Vector3(0, bottom + height / 2, 0))
		bottom += height
	var technique: Dictionary = view.get("technique", {})
	if float(technique.get("ice_ml", 0)) > 0:
		for index in 3:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE * 0.013
			_mesh(contents, "Ice%d" % index, cube, _material(Color(0.68, 0.84, 0.85, 0.8)), Vector3((index - 1) * 0.014, minf(0.091, maxf(0.018, bottom)), (index % 2) * 0.012 - 0.006))
	var aeration := float(technique.get("aeration", 0))
	if aeration > 0.05 and bottom > 0.010:
		var foam := CylinderMesh.new()
		foam.top_radius = 0.029
		foam.bottom_radius = 0.029
		foam.height = 0.0015
		foam.radial_segments = 12
		_mesh(contents, "Foam", foam, _material(Color(0.81, 0.82, 0.72, aeration)), Vector3(0, bottom, 0))
	return true

func set_held(value: bool) -> void:
	for material in materials:
		material.no_depth_test = value
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if value else BaseMaterial3D.SHADING_MODE_PER_PIXEL

static func make_preview(parent: Node) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(248, 350)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(viewport)
	var glass := FacetedGlassVisual.new()
	glass.name = "GlassVisual"
	viewport.add_child(glass)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.118
	camera.position = Vector3(0, 0.15, 0.6)
	camera.look_at(Vector3(0, HEIGHT / 2, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -35, 0)
	light.light_energy = 1.5
	viewport.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.84, 0.78)
	environment.environment.ambient_light_energy = 0.7
	viewport.add_child(environment)
	return viewport
