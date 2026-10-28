class_name FreeRoamCamera
extends AnchorCamera
## Ходьба с физическим телом; якорь — локальное рабочее место, не маршрут.

signal availability_changed

@export var free_roam_enabled: bool = false
@export var focus_anchor_ids: PackedStringArray = []
@export var walk_speed: float = 2.6
@export var focus_distance: float = 1.35
const EYE_HEIGHT := 1.65

var body: CharacterBody3D
var focus_active: bool = false
var _return_basis: Basis
var _nearby: PackedStringArray = []
var _dialogue_look: bool = false
var dialogue_pointer: bool = false

func set_dialogue_pointer(value: bool) -> void:
	if dialogue_pointer != value:
		dialogue_pointer = value
		_update_capture()


func set_dialogue_look(enabled: bool) -> void:
	_dialogue_look = free_roam_enabled and enabled
	if free_roam_enabled:
		_update_capture()


func configure(anchors_root: Node3D, initial_id: StringName) -> bool:
	if not super.configure(anchors_root, initial_id):
		return false
	if not free_roam_enabled:
		return true
	if body == null:
		body = CharacterBody3D.new()
		body.name = "WalkBody"
		body.top_level = true
		body.collision_layer = 4
		body.collision_mask = 5
		body.floor_snap_length = 0.15
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.24
		capsule.height = 1.8
		collision.shape = capsule
		collision.position.y = 0.9
		body.add_child(collision)
		add_child(body)
	body.global_position = global_position - Vector3.UP * EYE_HEIGHT
	current_anchor_id = &""
	focus_active = false
	return true


func can_move_to(anchor_id: StringName) -> bool:
	if not free_roam_enabled:
		return super.can_move_to(anchor_id)
	if not _controls_enabled or is_transitioning or focus_active or body == null:
		return false
	var anchor := get_anchor(anchor_id)
	if anchor == null or (not focus_anchor_ids.is_empty() and str(anchor_id) not in focus_anchor_ids):
		return false
	if view.global_position.distance_to(anchor.global_position) > focus_distance:
		return false
	var query := PhysicsRayQueryParameters3D.create(view.global_position, anchor.global_position, 1)
	return view.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func request_move(anchor_id: StringName) -> bool:
	if not free_roam_enabled:
		return super.request_move(anchor_id)
	if not can_move_to(anchor_id):
		return false
	_return_basis = view.global_basis
	if not super.request_move(anchor_id):
		return false
	focus_active = true
	body.velocity = Vector3.ZERO
	availability_changed.emit()
	return true


func try_focus() -> bool:
	if not free_roam_enabled:
		return false
	var nearest: AnchorPoint
	var distance := INF
	for anchor in get_anchors():
		if not can_move_to(anchor.anchor_id):
			continue
		var offset := anchor.global_position - view.global_position
		if offset.length() > 0.25 and -view.global_basis.z.dot(offset.normalized()) < 0.45:
			continue
		if offset.length() < distance:
			nearest = anchor
			distance = offset.length()
	return request_move(nearest.anchor_id) if nearest != null else false


func leave_focus() -> bool:
	if not free_roam_enabled or not focus_active or is_transitioning or not _controls_enabled:
		return false
	focus_active = false
	current_anchor_id = &""
	global_position = body.global_position + Vector3.UP * EYE_HEIGHT
	var forward := -_return_basis.z
	_anchor_yaw = atan2(-forward.x, -forward.z)
	_anchor_pitch = asin(clampf(forward.y, -1.0, 1.0))
	reset_look()
	availability_changed.emit()
	_update_capture()
	return true


func set_controls_enabled(enabled: bool) -> void:
	super.set_controls_enabled(enabled)
	if free_roam_enabled:
		if body != null and not enabled:
			body.velocity = Vector3.ZERO
		_update_capture()


func _update_capture() -> void:
	if not dialogue_pointer and ((_controls_enabled and not focus_active) or _dialogue_look) and not is_transitioning and _window_focused and view.current and DisplayServer.get_name() != "headless":
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		release_look()


func _input(event: InputEvent) -> void:
	if not free_roam_enabled:
		super._input(event)


func _unhandled_input(event: InputEvent) -> void:
	if not free_roam_enabled:
		super._unhandled_input(event)
		return
	if ((not _controls_enabled or focus_active) and not _dialogue_look) or is_transitioning or not _window_focused or not view.current:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look_delta(-event.screen_relative * mouse_sensitivity)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset_look"):
		reset_look()
		get_viewport().set_input_as_handled()


func apply_look_delta(delta: Vector2) -> void:
	if _dialogue_look and not is_transitioning and _window_focused:
		_look.x = wrapf(_look.x + delta.x, -PI, PI)
		var pitch := clampf(_anchor_pitch + _look.y + delta.y, deg_to_rad(-65), deg_to_rad(65))
		_look.y = pitch - _anchor_pitch
		_update_view_basis()
		return
	if free_roam_enabled and focus_active:
		return
	super.apply_look_delta(delta)


func _process(delta: float) -> void:
	if not free_roam_enabled:
		super._process(delta)
		return
	if _dialogue_look:
		if _window_focused:
			apply_look_delta(Vector2(Input.get_axis("look_right", "look_left"), Input.get_axis("look_down", "look_up")) * keyboard_look_speed * delta)
		_update_capture()
		return
	if _controls_enabled and not focus_active and view.current:
		super._process(delta)
		_update_capture()


func _physics_process(delta: float) -> void:
	if not free_roam_enabled or body == null or not _controls_enabled or focus_active or is_transitioning or not _window_focused or not view.current:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var heading := Basis(Vector3.UP, _anchor_yaw + _look.x)
	var direction := heading * Vector3(input.x, 0, input.y)
	body.velocity.x = direction.x * walk_speed
	body.velocity.z = direction.z * walk_speed
	body.velocity.y = -0.2 if body.is_on_floor() else body.velocity.y - 9.8 * delta
	body.move_and_slide()
	global_position = body.global_position + Vector3.UP * EYE_HEIGHT
	var nearby := PackedStringArray()
	for anchor in get_anchors():
		if can_move_to(anchor.anchor_id):
			nearby.append(str(anchor.anchor_id))
	if nearby != _nearby:
		_nearby = nearby
		availability_changed.emit()
