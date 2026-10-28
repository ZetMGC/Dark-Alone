class_name VisitorBehavior
extends Node
## TEST-маршрут в текущем баре. Правила разговора/напитка остаются в Session.

var state: StringName = &"docked"
var entrance := Vector3(0, 1.65, 4)
var waypoints: Array[Vector3] = [Vector3(-1.4, 1.65, 2.6), Vector3(-1.4, 1.65, -1.2)]
var guest: ServiceGuest
var model: VisitorModel
var camera: Camera3D
var session: NarrativeSession
var _dock: Transform3D
var _route: Array[Vector3] = []
var _speed: float = 0.0
var _settle: float = 0.0
var _leaving: bool = false
var _drink_time: float = -1.0
var _glass_home: Transform3D
var _glass: Node3D
var _grasp := Transform3D.IDENTITY
var _return_start := Transform3D.IDENTITY
var _returning: bool = false


func configure(actor: ServiceGuest, view: Camera3D, narrative: NarrativeSession) -> void:
	guest = actor
	model = actor.get_node("Body/VisitorModel")
	camera = view
	session = narrative
	_dock = guest.global_transform
	model.behavior_enabled = true
	_glass = guest.get_node("ServedGlass")
	var glass_world := _glass.global_transform
	_glass.top_level = true
	_glass.global_transform = glass_world
	guest.drink_presented.connect(func() -> void:
		# Main сначала показывает подачу, затем уточняет сосуд/точку: последний сигнал актуален.
		_drink_time = 0.0
		_glass = guest.get_node("ServedGlass")
		_glass_home = _glass.global_transform
		model.drink_weight = 0
		_returning = false
	)
	session.runner.node_changed.connect(_on_line)
	# Конец одной ветки не означает конец всей смены/общения.
	start_visit()


func start_visit() -> void:
	state = &"arriving"
	guest.show()
	guest.global_position = entrance
	_route = waypoints.duplicate()
	_route.append(_dock.origin)
	model.support_weight = 0
	_settle = 0
	_speed = 0


func request_departure() -> void:
	if state != &"docked" or session.runner.active or _drink_time >= 0:
		_leaving = true
		return
	state = &"releasing"
	_settle = 0.0
	_leaving = false


func _on_line(dialogue_id: StringName, node_id: StringName) -> void:
	# Авторские визуальные реакции TEST-ветки, без новых сюжетных фактов.
	if dialogue_id != &"test_war_cinema_guest":
		model.react(&"neutral")
		return
	var reactions := {&"opening": &"thoughtful", &"crates": &"tense", &"arms_reply": &"disagree", &"keepsakes_reply": &"thoughtful", &"props_reply": &"interested", &"set_reply": &"interested"}
	model.react(reactions.get(node_id, &"neutral"))


func _physics_process(delta: float) -> void:
	if not is_instance_valid(model):
		return
	guest.motion_available = state == &"docked"
	if not model.is_visible_in_tree():
		return
	model.attention = state == &"docked" and camera.global_position.distance_to(guest.global_position) < 4.5
	model.look_target = camera.global_position
	if session.mode in [NarrativeSession.JOURNAL, NarrativeSession.MENU]:
		return
	if state in [&"arriving", &"leaving"]:
		_walk(delta)
	elif state == &"settling":
		_settle += delta
		guest.rotation.y = lerp_angle(guest.rotation.y, _dock.basis.get_euler().y, 1.0 - exp(-delta * 5))
		model.support_weight = smoothstep(0.1, 0.8, _settle)
		if _settle >= 1.0:
			state = &"docked"
	elif state == &"releasing":
		_settle += delta
		model.support_weight = 1.0 - smoothstep(0, 0.65, _settle)
		if _settle > 0.7:
			state = &"leaving"
			_route = waypoints.duplicate()
			_route.reverse()
			_route.append(entrance)
	elif state == &"docked":
		if session.shift.finished:
			_leaving = true
		if _drink_time >= 0:
			_drink(delta)
		elif _leaving and not session.runner.active:
			request_departure()
	model.walk_speed = _speed


func _walk(delta: float) -> void:
	if _route.is_empty():
		return
	var offset := _route[0] - guest.global_position
	var remaining := offset.length()
	var heading := atan2(offset.x, offset.z) - PI / 2
	guest.rotation.y = lerp_angle(guest.rotation.y, heading, 1.0 - exp(-delta * 4))
	var facing := maxf(0, cos(angle_difference(guest.rotation.y, heading)))
	var desired := minf(0.75, sqrt(2.0 * 0.9 * remaining)) * facing
	_speed = move_toward(_speed, desired, delta * 0.9)
	var motion := offset.normalized() * minf(remaining, _speed * delta)
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.29
	shape.height = 1.75
	query.shape = shape
	query.transform.origin = guest.global_position + Vector3(0, -0.70, 0)
	query.motion = motion
	query.collision_mask = 5
	query.exclude = [guest.get_node("WalkObstacle").get_rid()]
	var fractions := guest.get_world_3d().direct_space_state.cast_motion(query)
	if fractions[0] < 0.99:
		_speed = 0
		return
	guest.global_position += motion
	model.travel_distance += motion.length()
	if remaining < 0.035:
		_route.remove_at(0)
		if _route.is_empty():
			_speed = 0
			if state == &"arriving":
				guest.global_position = _dock.origin
				state = &"settling"
			else:
				state = &"absent"
				guest.hide()


func _drink(delta: float) -> void:
	if not is_instance_valid(_glass):
		_drink_time = -1
		return
	_drink_time += delta
	var t := _drink_time
	var rest := model.to_global(Vector3(0.18, -0.48, 0.31))
	var mouth := model.to_global(Vector3(0.045, -0.27, 0.24))
	model.look_target = _glass.global_position
	model.drink_weight = smoothstep(0, 0.6, t) * (1.0 - smoothstep(4.1, 4.7, t))
	var lift := smoothstep(1.2, 2.0, t) * (1.0 - smoothstep(2.9, 3.8, t))
	model.drink_target = rest.lerp(mouth, lift)
	if t < 1.2:
		_glass.global_position = _glass_home.origin.lerp(rest + Vector3(0, 0.06, 0), smoothstep(0, 1.2, t))
		_grasp = model.hand_transform().affine_inverse() * _glass.global_transform
	elif t < 3.8:
		_glass.global_transform = model.hand_transform() * _grasp
		_glass.rotate_object_local(Vector3.RIGHT, -0.3 * lift)
	else:
		if not _returning:
			_return_start = _glass.global_transform
			_returning = true
		_glass.global_transform = _return_start.interpolate_with(_glass_home, smoothstep(3.8, 4.6, t))
	if t >= 4.8:
		_glass.global_transform = _glass_home
		model.drink_weight = 0
		_drink_time = -1
