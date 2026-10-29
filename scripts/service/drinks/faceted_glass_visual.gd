class_name FacetedGlassVisual
extends Node3D
## «Гранитоль» 240 мл и «Кромка» 60 мл: общая геометрия и содержимое для 3D/2D.
const HEIGHT := 0.105
const RADIUS := 0.034
const SHOT_HEIGHT := 0.070
const SHOT_RADIUS := 0.025
var is_shot: bool = false
var vessel_height: float = HEIGHT
var vessel_radius: float = RADIUS
var base_radius: float = 0.027
var floor_height: float = 0.010
var fill_height: float = 0.086
var inner_base: float = 0.025
var inner_top: float = 0.030
var segments: int = 12
var maker: String = "ГРАНИТОЛЬ"

func _init(shot: bool = false) -> void:
	is_shot = shot
	if shot:
		vessel_height = SHOT_HEIGHT
		vessel_radius = SHOT_RADIUS
		base_radius = 0.020
		floor_height = 0.014
		fill_height = 0.045
		inner_base = 0.0185
		inner_top = 0.0225
		segments = 16
		maker = "КРОМКА"

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
	var profile := [Vector2(0, 0), Vector2(base_radius, 0), Vector2(base_radius + 0.002, floor_height - 0.002), Vector2(vessel_radius, vessel_height - 0.008), Vector2(vessel_radius, vessel_height), Vector2(vessel_radius - 0.0025, vessel_height), Vector2(inner_base + 0.001, floor_height - 0.001), Vector2(0, floor_height - 0.001)]
	for row in range(profile.size() - 1):
		for side in segments:
			var corners := [_point(profile[row], side), _point(profile[row], side + 1), _point(profile[row + 1], side + 1), _point(profile[row + 1], side)]
			for index in [0, 1, 2, 0, 2, 3]:
				surface.set_smooth_group(-1)
				surface.add_vertex(corners[index])
	surface.generate_normals()
	_mesh(self, "Glass", surface.commit(), glass, Vector3.ZERO)
	var rim := TorusMesh.new()
	rim.inner_radius = vessel_radius - 0.0025
	rim.outer_radius = vessel_radius
	rim.rings = segments
	rim.ring_segments = 6
	_mesh(self, "Rim", rim, _material(Color(0.65, 0.75, 0.69, 0.75)), Vector3(0, vessel_height, 0))
	var bottom := CylinderMesh.new()
	bottom.top_radius = base_radius + 0.001
	bottom.bottom_radius = base_radius
	bottom.height = floor_height - 0.003
	bottom.radial_segments = segments
	_mesh(self, "ThickBase", bottom, _material(Color(0.53, 0.65, 0.59, 0.58)), Vector3(0, (floor_height - 0.002) / 2, 0))
	var stamp := Label3D.new()
	stamp.name = "MakerMark"
	stamp.text = maker
	stamp.font_size = 28
	stamp.pixel_size = 0.000075
	stamp.outline_size = 0
	stamp.modulate = Color(0.66, 0.74, 0.67, 0.75)
	stamp.position = Vector3(0, floor_height + 0.002, base_radius + 0.0025)
	add_child(stamp)
	contents = Node3D.new()
	contents.name = "Contents"
	add_child(contents)

func _point(profile: Vector2, side: int) -> Vector3:
	var angle := TAU * side / float(segments)
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
	var bottom := floor_height
	for index in view.layers.size():
		var layer: Dictionary = view.layers[index]
		var height := fill_height * float(layer.volume_ml) / float(view.vessel.capacity_ml)
		if height <= 0: continue
		var liquid := CylinderMesh.new()
		liquid.height = height
		liquid.bottom_radius = lerpf(inner_base, inner_top, (bottom - floor_height) / fill_height)
		liquid.top_radius = lerpf(inner_base, inner_top, (bottom + height - floor_height) / fill_height)
		liquid.radial_segments = segments
		var color: Array = layer.color
		_mesh(contents, "Layer%d" % index, liquid, _material(Color(color[0], color[1], color[2])), Vector3(0, bottom + height / 2, 0))
		bottom += height
	var technique: Dictionary = view.get("technique", {})
	if float(technique.get("ice_ml", 0)) > 0:
		for index in 3:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE * (0.010 if is_shot else 0.013)
			_mesh(contents, "Ice%d" % index, cube, _material(Color(0.68, 0.84, 0.85, 0.8)), Vector3((index - 1) * (0.010 if is_shot else 0.014), minf(vessel_height - 0.014, maxf(floor_height + 0.008, bottom)), (index % 2) * 0.010 - 0.005))
	var aeration := float(technique.get("aeration", 0))
	if aeration > 0.05 and bottom > floor_height:
		var foam := CylinderMesh.new()
		foam.top_radius = inner_top - 0.001
		foam.bottom_radius = inner_top - 0.001
		foam.height = 0.0015
		foam.radial_segments = segments
		_mesh(contents, "Foam", foam, _material(Color(0.81, 0.82, 0.72, aeration)), Vector3(0, bottom, 0))
	return true

func set_held(value: bool) -> void:
	for material in materials:
		material.no_depth_test = value
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if value else BaseMaterial3D.SHADING_MODE_PER_PIXEL

static func make_preview(parent: Node, shot: bool = false) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192, 210) if shot else Vector2i(248, 350)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(viewport)
	var glass := FacetedGlassVisual.new(shot)
	glass.name = "GlassVisual"
	viewport.add_child(glass)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.079 if shot else 0.118
	camera.position = Vector3(0, glass.vessel_height / 2 + 0.10, 0.6)
	camera.look_at(Vector3(0, glass.vessel_height / 2, 0))
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
