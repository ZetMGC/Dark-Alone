class_name AnchorCamera
extends Node3D
## Камера меняет позу только под непрозрачным fade; свободной ходьбы нет.

signal transition_started(from_id: StringName, to_id: StringName)
signal anchor_reached(anchor_id: StringName)

@export_range(0.02, 2.0) var fade_seconds: float = 0.22
@export_range(0.0, 1.0) var black_hold_seconds: float = 0.06
@export_range(0.001, 0.02) var mouse_sensitivity: float = 0.003
@export_range(0.1, 4.0) var keyboard_look_speed: float = 1.5

var current_anchor_id: StringName = &""
var is_transitioning: bool = false
var validation_errors: PackedStringArray = []

var _anchors: Dictionary = {}
var _controls_enabled: bool = true
var _look: Vector2 = Vector2.ZERO
var _anchor_yaw: float = 0.0
var _anchor_pitch: float = 0.0
var _transition: Tween
var _window_focused: bool = true
static var _preferred_look: float = 1.0
static var _preferred_duration: float = 0.5
var _look_control: HSlider
var _duration_control: HSlider
var _look_label: Label
var _duration_label: Label

@onready var view: Camera3D = $View
@onready var _fade: ColorRect = $FadeLayer/Fade


func configure_controls(hud: NavigationHUD) -> void:
	_look_control = hud.get_node("%LookSensitivity")
	_duration_control = hud.get_node("%TransitionDuration")
	_look_label = hud.get_node("%LookSensitivityLabel")
	_duration_label = hud.get_node("%TransitionDurationLabel")
	_look_control.value_changed.connect(set_look_sensitivity)
	_duration_control.value_changed.connect(set_transition_duration)
	hud.get_node("%ResetCamera").pressed.connect(func() -> void:
		set_look_sensitivity(1.0)
		set_transition_duration(0.5)
	)
	set_look_sensitivity(_preferred_look)
	set_transition_duration(_preferred_duration)


func set_look_sensitivity(multiplier: float) -> void:
	if not is_finite(multiplier):
		return
	_preferred_look = clampf(multiplier, 0.5, 2.0)
	mouse_sensitivity = 0.003 * _preferred_look
	keyboard_look_speed = 1.5 * _preferred_look
	if is_instance_valid(_look_control):
		_look_control.set_value_no_signal(_preferred_look)
		_look_label.text = "Скорость обзора: %d%%" % roundi(_preferred_look * 100.0)


func apply_preferences() -> void:
	set_look_sensitivity(_preferred_look)
	set_transition_duration(_preferred_duration)


func set_transition_duration(seconds: float) -> void:
	if not is_finite(seconds):
		return
	_preferred_duration = clampf(seconds, 0.2, 1.0)
	black_hold_seconds = 0.06
	fade_seconds = (_preferred_duration - black_hold_seconds) * 0.5
	if is_instance_valid(_duration_control):
		_duration_control.set_value_no_signal(_preferred_duration)
		_duration_label.text = "Переход между точками: %.2f с" % _preferred_duration


func configure(anchors_root: Node3D, initial_id: StringName) -> bool:
	if is_transitioning:
		return false
	var candidates: Dictionary = {}
	var errors: PackedStringArray = []
	if not is_instance_valid(anchors_root):
		validation_errors = PackedStringArray(["Не задан корень якорей"])
		return false
	for child in anchors_root.get_children():
		if not child is AnchorPoint:
			continue
		var anchor := child as AnchorPoint
		if anchor.anchor_id == &"":
			errors.append("Пустой ID якоря: " + str(anchor.name))
		elif candidates.has(anchor.anchor_id):
			errors.append("Повтор ID якоря: " + str(anchor.anchor_id))
		else:
			candidates[anchor.anchor_id] = anchor
		if not anchor.global_transform.is_finite():
			errors.append("Некорректная поза: " + str(anchor.anchor_id))
		elif not anchor.global_basis.is_equal_approx(anchor.global_basis.orthonormalized()):
			errors.append("Масштаб якоря должен быть единичным: " + str(anchor.anchor_id))
	if candidates.is_empty():
		errors.append("Граф якорей пуст")
	for anchor: AnchorPoint in candidates.values():
		var seen: Dictionary = {}
		for neighbour in anchor.neighbours:
			if not candidates.has(StringName(neighbour)):
				errors.append("Неизвестный сосед %s у %s" % [neighbour, anchor.anchor_id])
			if StringName(neighbour) == anchor.anchor_id or seen.has(neighbour):
				errors.append("Самоссылка или повтор связи у " + str(anchor.anchor_id))
			seen[neighbour] = true
	if not candidates.has(initial_id):
		errors.append("Нет стартового якоря: " + str(initial_id))
	validation_errors = errors
	if not errors.is_empty():
		return false
	_anchors = candidates
	current_anchor_id = initial_id
	_place_at(initial_id)
	_fade.color.a = 0.0
	return true


func get_anchor(anchor_id: StringName) -> AnchorPoint:
	return _anchors.get(anchor_id) as AnchorPoint


func get_anchors() -> Array[AnchorPoint]:
	var result: Array[AnchorPoint] = []
	for anchor: AnchorPoint in _anchors.values():
		result.append(anchor)
	return result


func can_move_to(anchor_id: StringName) -> bool:
	if not _controls_enabled or is_transitioning or not _anchors.has(current_anchor_id):
		return false
	return anchor_id != current_anchor_id and _anchors.has(anchor_id) \
		and str(anchor_id) in get_anchor(current_anchor_id).neighbours


func request_move(anchor_id: StringName) -> bool:
	if not can_move_to(anchor_id):
		return false
	is_transitioning = true
	release_look()
	# Состояние блокируется до сигнала: обработчик не может запустить второй переход.
	transition_started.emit(current_anchor_id, anchor_id)
	_transition = create_tween()
	_transition.tween_property(_fade, "color:a", 1.0, fade_seconds)
	_transition.tween_callback(_place_at.bind(anchor_id))
	_transition.tween_interval(black_hold_seconds)
	_transition.tween_property(_fade, "color:a", 0.0, fade_seconds)
	_transition.tween_callback(_complete_transition.bind(anchor_id))
	return true


func _place_at(anchor_id: StringName) -> void:
	global_transform = get_anchor(anchor_id).global_transform
	var forward := -global_basis.z.normalized()
	_anchor_yaw = atan2(-forward.x, -forward.z)
	_anchor_pitch = asin(clampf(forward.y, -1.0, 1.0))
	reset_look()


func _complete_transition(anchor_id: StringName) -> void:
	current_anchor_id = anchor_id
	is_transitioning = false
	anchor_reached.emit(anchor_id)


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		release_look()


func reset_look() -> void:
	_look = Vector2.ZERO
	if is_node_ready():
		_update_view_basis()


func _update_view_basis() -> void:
	# Yaw вокруг вертикали мира, pitch вокруг горизонтальной оси взгляда.
	# Наклон якоря не должен наклонять ось вращения при осмотре комнаты.
	view.global_basis = Basis(Vector3.UP, _anchor_yaw + _look.x) * Basis(Vector3.RIGHT, _anchor_pitch + _look.y)


func release_look() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	# Release должен сработать даже над элементами UI.
	if event.is_action_released("look"):
		release_look()


func _unhandled_input(event: InputEvent) -> void:
	if not _controls_enabled or is_transitioning or not _window_focused:
		return
	if event.is_action_pressed("look"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look_delta(-event.screen_relative * mouse_sensitivity)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset_look"):
		reset_look()
		get_viewport().set_input_as_handled()


func apply_look_delta(delta: Vector2) -> void:
	if not _controls_enabled or is_transitioning:
		return
	_look.x = wrapf(_look.x + delta.x, -PI, PI)
	var pitch := clampf(_anchor_pitch + _look.y + delta.y, deg_to_rad(-65), deg_to_rad(65))
	_look.y = pitch - _anchor_pitch
	_update_view_basis()


func _process(delta: float) -> void:
	if not _controls_enabled or is_transitioning or not _window_focused:
		return
	var direction := Vector2(
		Input.get_axis("look_right", "look_left"),
		Input.get_axis("look_down", "look_up")
	)
	if direction != Vector2.ZERO:
		apply_look_delta(direction * keyboard_look_speed * delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
		release_look()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true


func _exit_tree() -> void:
	release_look()
	if _transition != null and _transition.is_valid():
		_transition.kill()
