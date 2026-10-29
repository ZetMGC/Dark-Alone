class_name BottleCapItem
extends Control
## Независимая крышка: остаётся на столе, переносится мышью, закрывается при отпускании на горлышке.

signal return_requested
signal dropped
signal motion_finished(attached: bool)
const DURATION := 0.26
const DIMENSIONS := Vector2(29, 29)
var texture: Texture2D
var logical_position := Vector2.ZERO
var detached: bool = false
var animating: bool = false
var returning: bool = false
var _elapsed: float = 0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _view_origin := Vector2.ZERO
var _view_scale: float = 1
var _pressed: bool = false
var _moving: bool = false
var _press_point := Vector2.ZERO
var _grab_position := Vector2.ZERO
var input_enabled: bool = true
var external_drag: bool = false
var motion := TabletopMotion.new()
var _velocity := Vector2.ZERO
var _last_motion: int = 0
var _rotation: float = 0
var _return_rotation: float = 0
var target_rotation: float = 0

func _ready() -> void:
	motion.half_size = DIMENSIONS / 2
	motion.is_cap = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func set_view(origin: Vector2, scale_value: float) -> void:
	_view_origin = origin
	_view_scale = scale_value
	_sync()

func logical_rect() -> Rect2:
	return Rect2(logical_position, DIMENSIONS)

func start_motion(from: Vector2, to: Vector2, attach: bool, radians: float = 0) -> void:
	_pressed = false
	_moving = false
	external_drag = false
	motion.active = false
	_return_rotation = _rotation
	target_rotation = radians
	_from = from
	_to = to
	returning = attach
	_elapsed = 0
	animating = true
	detached = true
	logical_position = from
	show()
	_sync()

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	if not animating:
		if detached and not _pressed and motion.active:
			motion.advance(delta)
			logical_position = motion.center() - DIMENSIONS / 2
			_rotation = motion.angle
			_sync()
		return
	_elapsed = minf(DURATION, _elapsed + delta)
	var t := _elapsed / DURATION
	var eased := t * t * (3.0 - 2.0 * t)
	# Короткая дуга: при снятии сначала поднимается, при возврате опускается на горлышко.
	logical_position = _from.lerp(_to, eased) + Vector2(0, -sin(PI * eased) * 24)
	_rotation = lerp_angle(_return_rotation, target_rotation, eased)
	_sync()
	if _elapsed >= DURATION:
		animating = false
		detached = not returning
		visible = detached
		motion_finished.emit(returning)

func cancel_drag() -> void:
	if _pressed and detached:
		_velocity = Vector2.ZERO
		_moving = true
		release_pointer()
	_pressed = false
	_moving = false
	external_drag = false

func _sync() -> void:
	position = _view_origin + logical_position * _view_scale
	size = DIMENSIONS * _view_scale
	queue_redraw()

func _draw() -> void:
	if texture == null: return
	var ground_y := maxf(TabletopMotion.TABLE.position.y + 18, logical_position.y + 27)
	var lift := maxf(0, ground_y - logical_position.y - 27)
	if motion.active and not _pressed:
		ground_y = motion.ground.y
		lift = motion.elevation
	elif _pressed:
		ground_y = minf(TabletopMotion.TABLE.end.y, ground_y + 18)
		lift += 18
	var view := Transform2D(Vector2(_view_scale, 0), Vector2(0, _view_scale), Vector2.ZERO)
	TabletopMotion.shadow(self, view, Vector2(14.5, ground_y - logical_position.y), Vector2(10, 3), 0, lift, 0.35)
	var twist := sin((_elapsed / DURATION) * TAU * 2) * 0.12 if animating and returning else 0.0
	draw_set_transform(size / 2, _rotation + twist)
	draw_texture_rect(texture, Rect2(-size / 2 + Vector2.ONE * 2 * _view_scale, size - Vector2.ONE * 4 * _view_scale), false)

func take_from_bottle(at: Vector2, pointer: Vector2, radians: float = 0) -> void:
	detached = true
	animating = false
	logical_position = at
	_rotation = radians
	show()
	press_pointer(pointer)
	_moving = true
	external_drag = true
	_sync()

func press_pointer(pointer: Vector2) -> void:
	motion.active = false
	_pressed = true
	_moving = false
	_press_point = pointer
	_grab_position = logical_position
	_velocity = Vector2.ZERO
	_last_motion = Time.get_ticks_usec()

func drag_pointer(pointer: Vector2) -> void:
	if not _pressed: return
	var travel := pointer - _press_point
	_moving = _moving or travel.length() > 5
	if _moving:
		var old := logical_position
		logical_position = (_grab_position + travel).clamp(Vector2(20, 120), Vector2(1230, 598))
		var now := Time.get_ticks_usec()
		var elapsed := clampf((now - _last_motion) / 1000000.0, 1.0 / 120.0, 0.1)
		if logical_position.distance_to(old) > 0.1:
			_velocity = _velocity.lerp(((logical_position - old) / elapsed).limit_length(1400), 0.7)
			_last_motion = now
		_sync()

func release_pointer() -> void:
	if not _pressed: return
	_pressed = false
	external_drag = false
	dropped.emit()
	if animating: return
	if detached:
		var speed := _velocity * clampf(1 - (Time.get_ticks_usec() - _last_motion) / 120000.0, 0, 1)
		# Физическая поза строится из текущего центра, не меняя положение в кадре release.
		var origin := logical_position + DIMENSIONS / 2 - Vector2(0, DIMENSIONS.y / 2).rotated(_rotation)
		motion.release(origin, _rotation, speed, 0.008)
	_moving = false

func _gui_input(event: InputEvent) -> void:
	if not input_enabled or animating: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_pointer((event.global_position - _view_origin) / _view_scale)
		elif _pressed:
			release_pointer()
		accept_event()
	elif event is InputEventMouseMotion and _pressed:
		drag_pointer((event.global_position - _view_origin) / _view_scale)
		accept_event()
